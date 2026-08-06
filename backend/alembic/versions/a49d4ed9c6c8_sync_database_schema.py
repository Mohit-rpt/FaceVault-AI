"""sync_database_schema

Revision ID: a49d4ed9c6c8
Revises: 
Create Date: 2026-08-06 08:25:01.326245

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a49d4ed9c6c8'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema safely."""
    # Add missing columns to person_details
    op.add_column('person_details', sa.Column('gender', sa.String(length=20), nullable=True))
    op.add_column('person_details', sa.Column('department', sa.String(length=100), nullable=True))
    op.add_column('person_details', sa.Column('employee_id', sa.String(length=50), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('person_details', 'employee_id')
    op.drop_column('person_details', 'department')
    op.drop_column('person_details', 'gender')
