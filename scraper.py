#!/usr/bin/env python

import time

import requests

from sqlalchemy import Column, ForeignKey, Integer, String, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, sessionmaker


# CLASSES

Base = declarative_base()


class Image(Base):
    __tablename__ = 'images'

    id = Column(Integer, primary_key=True)
    pageid = Column(Integer, unique=True)
    title = Column(String(1023))
    author = Column(String(255))
    archiveid = Column(String(127))
    year = Column(Integer, index=True)
    month = Column(Integer)
    day = Column(Integer)
    url = Column(String(1023))
    mime = Column(String(255))
    width = Column(Integer)
    height = Column(Integer)
    wikilinks = relationship('WikiLink')

    def __repr__(self):
        return "<Image (pageid=%i)>" % (self.pageid)

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

        image = Image(
            pageid=image_data['pageid'],
            title=None,
            author=None,
            archiveid=None,
            year=None,
            month=None,
            day=None,
            url=info['url'],
            mime=info['mime'],
            width=info['width'],
            height=info['height']
        )

        if meta is not None:
            for pair in meta:
                name = pair['name']
                if name == 'Headline':
                    image.title = get_value(pair)
                elif name == 'ObjectName':
                    image.archiveid = get_value(pair)
                elif name == 'Artist':
                    image.author = get_value(pair)
                elif name == 'DateTimeOriginal':
                    dateString = get_value(pair).split()[0]
                    try:
                        image.year, image.month, image.day = map(int, dateString.split(':'))
                    except ValueError:
                        print dateString
                        raise

        return image


class WikiLink(Base):
    __tablename__ = 'wikilinks'

    id = Column(Integer, primary_key=True)
    url = Column(String(255))
    imageid = Column(Integer, ForeignKey('images.id', ondelete='CASCADE'), index=True)


# IMAGE SCRAPING

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
        'iiprop': 'url|size|mime|metadata'
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

def scrape_images(session):
    start_time = time.time()

    for image_data in iterate_image_data():
        img = Image.create_from_image_data(image_data)
        if img.title is not None and img.year is not None:
            session.add(img)
            session.commit()

    print('got images, time elapsed: %is' % (time.time() - start_time))


# LINK SCRAPING

def iterate_image_batches(batch_size):
    batch_start = 0
    while True:
        images = list(session.query(Image).offset(batch_start).limit(batch_size))
        batch_start = batch_start + batch_size

        if len(images) == 0:
            return

        yield images

def request_image_usage(batch):
    print('Querying 50 image usages')

    params = {
        'format': 'json',
        'action': 'query',
        'pageids': '|'.join([str(img.pageid) for img in batch]),
        'prop': 'globalusage',
        'guprop': 'url|namespace',
        'gulimit': 500
    }

    res = requests.get('http://commons.wikimedia.org/w/api.php', params=params)
    return res.json['query']['pages']

def iterate_image_usage(batch):
    usages = request_image_usage(batch)
    for usage in usages.itervalues():
        yield usage

def scrape_wiki_links(session):
    start_time = time.time()

    for batch in iterate_image_batches(50):
        for usage in iterate_image_usage(batch):
            pageid = usage['pageid']
            globalusage = usage['globalusage']
            for gu in globalusage:
                if gu['wiki'] == 'de.wikipedia.org' and gu['ns'] == '0':
                    link = WikiLink(url=gu['url'])
                    session.add(link)

                    img = session.query(Image).filter_by(pageid=pageid).first()
                    img.wikilinks.append(link)
        session.commit()

    print('got links, time elapsed: %is' % (time.time() - start_time))


# MAIN

if __name__ == '__main__':
    engine = create_engine('mysql://root@localhost/ccplay')
    Base.metadata.create_all(engine)

    Session = sessionmaker(bind=engine)
    session = Session()

    scrape_images(session)
    scrape_wiki_links(session)
