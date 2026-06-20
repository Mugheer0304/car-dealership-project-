"""Initial schema – cars and inquiries

Revision ID: 001_initial
Revises:
Create Date: 2024-01-01 00:00:00
"""
from alembic import op
import sqlalchemy as sa

revision = '001_initial'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'cars',
        sa.Column('id',           sa.Integer(),     nullable=False),
        sa.Column('make',         sa.String(50),    nullable=False),
        sa.Column('model',        sa.String(50),    nullable=False),
        sa.Column('year',         sa.Integer(),     nullable=False),
        sa.Column('trim',         sa.String(100),   nullable=True),
        sa.Column('price',        sa.Float(),       nullable=False),
        sa.Column('mileage',      sa.Integer(),     nullable=False, server_default='0'),
        sa.Column('color',        sa.String(50),    nullable=True),
        sa.Column('fuel_type',    sa.String(30),    nullable=True),
        sa.Column('transmission', sa.String(30),    nullable=True),
        sa.Column('condition',    sa.String(10),    nullable=False, server_default='used'),
        sa.Column('vin',          sa.String(17),    nullable=True),
        sa.Column('image_url',    sa.String(500),   nullable=True),
        sa.Column('description',  sa.Text(),        nullable=True),
        sa.Column('available',    sa.Boolean(),     nullable=False, server_default='true'),
        sa.Column('created_at',   sa.DateTime(),    server_default=sa.func.now()),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('vin'),
    )
    op.create_index('ix_cars_make',  'cars', ['make'])
    op.create_index('ix_cars_model', 'cars', ['model'])
    op.create_index('ix_cars_year',  'cars', ['year'])

    op.create_table(
        'inquiries',
        sa.Column('id',         sa.Integer(),    nullable=False),
        sa.Column('name',       sa.String(100),  nullable=False),
        sa.Column('email',      sa.String(200),  nullable=False),
        sa.Column('phone',      sa.String(30),   nullable=True),
        sa.Column('message',    sa.Text(),       nullable=False),
        sa.Column('car_id',     sa.Integer(),    nullable=True),
        sa.Column('created_at', sa.DateTime(),   server_default=sa.func.now()),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_inquiries_email', 'inquiries', ['email'])


def downgrade() -> None:
    op.drop_table('inquiries')
    op.drop_table('cars')
