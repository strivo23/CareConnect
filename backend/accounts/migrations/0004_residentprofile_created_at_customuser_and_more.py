import django.db.models.deletion
import django.utils.timezone
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0003_residentprofile"),
        ("auth", "0012_alter_user_first_name_max_length"),
    ]

    operations = [
        # Rename the actual DB table from accounts_user to accounts_customuser
        # (0001-0003 were applied when model was still named 'User')
        # Uses RunPython so the rename is skipped on a fresh DB (e.g. test setup).
        migrations.RunPython(
            code=lambda apps, schema_editor: (
                schema_editor.execute(
                    "ALTER TABLE accounts_user RENAME TO accounts_customuser;"
                )
                if schema_editor.connection.introspection.table_names().__contains__("accounts_user")
                else None
            ),
            reverse_code=lambda apps, schema_editor: (
                schema_editor.execute(
                    "ALTER TABLE accounts_customuser RENAME TO accounts_user;"
                )
                if schema_editor.connection.introspection.table_names().__contains__("accounts_customuser")
                else None
            ),
        ),

        # Update the role choices to match the new model definition
        migrations.AlterField(
            model_name="customuser",
            name="role",
            field=models.CharField(
                choices=[
                    ("ADMIN", "Admin"),
                    ("RESIDENT", "Resident"),
                    ("SECURITY", "Security"),
                    ("STAFF", "Staff"),
                ],
                default="RESIDENT",
                max_length=20,
            ),
        ),

        # Update full_name to remove blank=True
        migrations.AlterField(
            model_name="customuser",
            name="full_name",
            field=models.CharField(max_length=255),
        ),

        # Add the created_at field to ResidentProfile
        migrations.AddField(
            model_name="residentprofile",
            name="created_at",
            field=models.DateTimeField(
                auto_now_add=True, default=django.utils.timezone.now
            ),
            preserve_default=False,
        ),

        # Update ResidentProfile.user to OneToOneField
        migrations.AlterField(
            model_name="residentprofile",
            name="user",
            field=models.OneToOneField(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="resident_profile",
                to=settings.AUTH_USER_MODEL,
            ),
        ),
    ]
