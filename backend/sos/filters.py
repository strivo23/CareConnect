"""
sos/filters.py

DjangoFilterBackend filter set for SOSIncident.
"""

import django_filters
from .models import SOSIncident


class SOSIncidentFilter(django_filters.FilterSet):
    """
    Supports filtering SOSIncident queryset by:
      - status        (exact)
      - category      (exact FK id)
      - resident      (exact FK id)
      - created_after / created_before (date range)
    """

    # Date-range helpers
    created_after = django_filters.DateFilter(
        field_name="created_at",
        lookup_expr="date__gte",
        label="Created on or after (YYYY-MM-DD)",
    )
    created_before = django_filters.DateFilter(
        field_name="created_at",
        lookup_expr="date__lte",
        label="Created on or before (YYYY-MM-DD)",
    )

    class Meta:
        model = SOSIncident
        fields = {
            "status": ["exact"],
            "category": ["exact"],
            "resident": ["exact"],
        }
