"""
careconnect/celery.py

Celery configuration for CareConnect backend project.
Integrates Celery with Django settings and enables task autodiscovery across all apps.
"""

import os
from celery import Celery

# Set default Django settings module for 'celery' program.
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'careconnect.settings')

app = Celery('careconnect')

# Using a string here means the worker doesn't have to serialize
# the configuration object to child processes.
# - namespace='CELERY' means all celery-related config keys should have a `CELERY_` prefix.
app.config_from_object('django.conf:settings', namespace='CELERY')

# Load task modules from all registered Django app configs.
app.autodiscover_tasks()
try:
    import sos.tasks  # noqa
except Exception:
    pass


@app.task(bind=True, ignore_result=True)
def debug_task(self):
    print(f'Request: {self.request!r}')
