from django.db import models
from django.conf import settings

class Society(models.Model):
    STATUS_CHOICES = [
        ('Active', 'Active'),
        ('Inactive', 'Inactive'),
    ]
    name = models.CharField(max_length=255)
    code = models.CharField(max_length=50, blank=True, null=True, unique=True)
    address = models.TextField()
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    pincode = models.CharField(max_length=20)
    country = models.CharField(max_length=100, default='India')
    description = models.TextField(blank=True, null=True)

    # Legacy fields retained for backward database compatibility
    contact_person = models.CharField(max_length=255, blank=True, null=True)
    contact_number = models.CharField(max_length=20, blank=True, null=True)
    email = models.EmailField(blank=True, null=True)
    number_of_blocks = models.IntegerField(default=0)
    total_flats = models.IntegerField(default=0)

    society_manager = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="managed_societies"
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Active')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.name} ({self.code or 'No Code'})"

    class Meta:
        verbose_name_plural = "Societies"
        ordering = ["-created_at"]


class BlockTower(models.Model):
    STATUS_CHOICES = [
        ('Active', 'Active'),
        ('Inactive', 'Inactive'),
    ]
    society = models.ForeignKey(Society, on_delete=models.CASCADE, related_name='blocks')
    name = models.CharField(max_length=100)
    total_floors = models.IntegerField(default=1)
    total_flats = models.IntegerField(default=0)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Active')
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)

    def __str__(self):
        return f"{self.society.name} - {self.name}"

    class Meta:
        verbose_name = "Block / Wing"
        verbose_name_plural = "Blocks / Wings"
        ordering = ["name"]


class Flat(models.Model):
    block = models.ForeignKey(BlockTower, on_delete=models.CASCADE, related_name='flats')
    flat_number = models.CharField(max_length=50)
    floor = models.IntegerField(default=1)
    type = models.CharField(max_length=50, default='2BHK')
    occupied = models.BooleanField(default=False)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='owned_flats'
    )
    owner_name = models.CharField(max_length=255, blank=True, null=True)
    resident_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='occupied_flats'
    )
    resident_name = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)

    def __str__(self):
        return f"{self.block.name} - Flat {self.flat_number}"

    class Meta:
        ordering = ["flat_number"]
