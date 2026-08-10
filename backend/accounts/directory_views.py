from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.pagination import PageNumberPagination
from .directory_service import ContactDirectoryService


class ContactDirectoryAPIView(APIView):
    """
    GET /api/directory/
    Society-scoped contact directory with privacy masking and role filters.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        params = request.query_params.dict()
        contacts = ContactDirectoryService.get_directory_contacts(request.user, params)

        paginator = PageNumberPagination()
        paginator.page_size = 20
        page = paginator.paginate_queryset(contacts, request)
        if page is not None:
            return paginator.get_paginated_response(page)

        return Response({
            "success": True,
            "count": len(contacts),
            "results": contacts
        }, status=status.HTTP_200_OK)
