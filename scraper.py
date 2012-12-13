#!/usr/bin/env python

import time

import requests

from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

def request_pages(gcmcontinue):
    print('Querying 500 images')

    params = {
        'format': 'json',
        'action': 'query',
        'generator': 'categorymembers',
        'gcmtitle': 'Category:Images_from_the_German_Federal_Archive',
        'gcmtype': 'file',
        'gcmlimit': 500,
        'gcmcontinue': gcmcontinue,
        'prop': 'imageinfo',
        'iiprop': 'url|size|sha1|mime|metadata'
    }

    res = requests.get('http://commons.wikimedia.org/w/api.php', params=params)
    res_data = res.json
    pages = res_data['query']['pages']

    if 'query-continue' in res_data:
        cont = res_data['query-continue']['categorymembers']['gcmcontinue']
        return pages, cont
    else:
        return pages, None

def iterate_image_data():
    cont = None
    while True:
        pages, cont = request_pages(cont)

        for image_data in pages.itervalues():
            yield image_data

        if cont is None:
            return

Base = declarative_base()

class CCPlayImage(Base):
    __tablename__ = 'CCPlayImages'

    pageid = Column(Integer, primary_key=True)
    title = Column(String(1023))
    author = Column(String(255))
    archiveid = Column(String(127))
    url = Column(String(1023))
    mime = Column(String(255))
    sha1 = Column(String(40))
    width = Column(Integer)
    height = Column(Integer)

    def __repr__(self):
        return "<CCPlayImage (pageid=%i)>" % (self.pageid)

    @classmethod
    def create_from_image_data(cls, image_data):
        def get_value(pair):
            if isinstance(pair['value'], basestring):
                value = pair['value']
            else:
                value = pair['value'][0]['value']
            return value.strip(' \n\r')

        info = image_data['imageinfo'][0]
        meta = info['metadata']

        title = None
        author = None
        archiveid = None

        if meta is not None:
            for pair in meta:
                if pair['name'] == 'Headline':
                    title = get_value(pair)
                elif pair['name'] == 'ObjectName':
                    archiveid = get_value(pair)
                elif pair['name'] == 'Artist':
                    author = get_value(pair)

        return CCPlayImage(
            pageid=image_data['pageid'],
            title=title,
            author=author,
            archiveid=archiveid,
            url=info['url'],
            mime=info['mime'],
            sha1=info['sha1'],
            width=info['width'],
            height=info['height']
        )

if __name__ == '__main__':
    start_time = time.time()
    engine = create_engine('mysql://root@localhost/ccplay')
    Base.metadata.create_all(engine)

    Session = sessionmaker(bind=engine)
    session = Session()

    for image_data in iterate_image_data():
        img = CCPlayImage.create_from_image_data(image_data)
        session.add(img)
        session.commit()

    print('time elapsed: %is' % (time.time() - start_time))
