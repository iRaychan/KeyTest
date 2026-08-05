-- KeySuite V2.29 Coupling Selector and Pumpset Description
-- Upgrade path: V2.28 -> V2.29
begin;

-- User-confirmed correction: FCL 224 is permitted up to 3,000 rpm.
update public.ks_products_coupling c
set max_speed_rpm=3000,
    updated_at=now()
where c.component_type='pin_bush'
  and upper(c.model)='FCL 224';

commit;

-- Verification result: should return FCL 224 / 3000.
select model,max_speed_rpm
from public.ks_products_coupling
where component_type='pin_bush' and upper(model)='FCL 224';
