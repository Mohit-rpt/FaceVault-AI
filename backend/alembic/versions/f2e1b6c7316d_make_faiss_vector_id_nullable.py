"""make_faiss_vector_id_nullable

Revision ID: f2e1b6c7316d
Revises: a49d4ed9c6c8
Create Date: 2026-08-06 08:44:10.592055

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f2e1b6c7316d'
down_revision: Union[str, Sequence[str], None] = 'a49d4ed9c6c8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema safely."""
    op.alter_column('face_embeddings', 'faiss_vector_id',
               existing_type=sa.INTEGER(),
               nullable=True)


def downgrade() -> None:
    """Downgrade schema."""
    op.alter_column('face_embeddings', 'faiss_vector_id',
               existing_type=sa.INTEGER(),
               nullable=False)
