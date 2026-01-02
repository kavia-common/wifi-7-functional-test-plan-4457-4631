from celery import Celery
import os
broker = os.environ.get('CELERY_BROKER_URL', 'redis://localhost:6379/0')
celery = Celery('coredoc', broker=broker)
