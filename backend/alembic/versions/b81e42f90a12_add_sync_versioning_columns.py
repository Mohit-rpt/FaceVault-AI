"""Add sync versioning and soft deletion columns to persons and face_embeddings tables

Revision ID: b81e42f90a12
Revises: f2e1b6c7316d
Create Date: 2026-08-07 09:26:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'b81e42f90a12'
down_revision = 'f2e1b6c7316d'
branch_labels = None
depends_on = None


def upgrade():
    # Add columns to persons table
    op.add_column('persons', sa.Column('is_deleted', sa.Boolean(), server_default='false', nullable=False))

    # Add columns to face_embeddings table
    op.add_column('face_embeddings', sa.Column('embedding_version', sa.Integer(), server_default='1', nullable=False))
    op.add_column('face_embeddings', sa.Column('updated_at', sa.DateTime(), server_default=sa.text('NOW()'), nullable=True))
    op.add_column('face_embeddings', sa.Column('is_deleted', sa.Boolean(), server_default='false', nullable=False))
    
    op.create_index('ix_face_embeddings_embedding_version', 'face_embeddings', ['embedding_version'])


def downgrade():
    op.drop_index('ix_face_embeddings_embedding_version', table_name='face_embeddings')
    op.drop_column('face_embeddings', 'is_deleted')
    op.drop_column('face_embeddings', 'updated_at')
    op.drop_column('face_embeddings', 'embedding_version')
    op.drop_column('persons', 'is_deleted')
