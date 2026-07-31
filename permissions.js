(() => {
  'use strict';
  const ROLES=['viewer','dealer','user','admin','owner'];
  const DEFAULTS={
    viewer:{key_dashboard:'none',manage_roles:'none',company_pricing:'none',manage_categories:'none',manage_price_list:'none',change_fuel_price:'none',view_customers:'assigned',edit_customers:'none',customer_assignment:'none',create_quotations:'none',view_quotations:'assigned',own_profile:'full'},
    dealer:{key_dashboard:'none',manage_roles:'none',company_pricing:'none',manage_categories:'none',manage_price_list:'none',change_fuel_price:'none',view_customers:'own',edit_customers:'own',customer_assignment:'none',create_quotations:'full',view_quotations:'own',own_profile:'full'},
    user:{key_dashboard:'none',manage_roles:'none',company_pricing:'none',manage_categories:'none',manage_price_list:'none',change_fuel_price:'none',view_customers:'assigned',edit_customers:'assigned',customer_assignment:'none',create_quotations:'full',view_quotations:'assigned',own_profile:'full'},
    admin:{key_dashboard:'none',manage_roles:'none',company_pricing:'none',manage_categories:'none',manage_price_list:'none',change_fuel_price:'none',view_customers:'all',edit_customers:'all',customer_assignment:'full',create_quotations:'full',view_quotations:'all',own_profile:'full'},
    owner:{key_dashboard:'full',manage_roles:'full',company_pricing:'full',manage_categories:'full',manage_price_list:'full',change_fuel_price:'full',view_customers:'all',edit_customers:'all',customer_assignment:'full',create_quotations:'full',view_quotations:'all',own_profile:'full'}
  };
  let matrix=structuredClone(DEFAULTS);
  const normalize=(value)=>String(value||'none').toLowerCase();
  function merge(next){
    const merged=structuredClone(DEFAULTS);
    (Array.isArray(next)?next:[]).forEach(row=>{
      const role=normalize(row.role);
      if(!ROLES.includes(role))return;
      let permissions=row.permissions||{};
      if(typeof permissions==='string'){try{permissions=JSON.parse(permissions)}catch(_){permissions={}}}
      merged[role]={...merged[role],...permissions};
    });
    if(next && !Array.isArray(next) && typeof next==='object'){
      ROLES.forEach(role=>{if(next[role])merged[role]={...merged[role],...next[role]}});
    }
    matrix=merged;
    window.KEYSUITE_ROLE_PERMISSIONS=structuredClone(matrix);
    window.dispatchEvent(new CustomEvent('keysuite-permissions-changed',{detail:{matrix:structuredClone(matrix)}}));
    return matrix;
  }
  function currentRole(){return normalize(window.KEYSUITE_ACCESS?.role||window.KEYSUITE_PROFILE?.role||'viewer')}
  function level(key,role=currentRole()){return normalize(matrix[normalize(role)]?.[key]??DEFAULTS[normalize(role)]?.[key]??'none')}
  function can(key,role=currentRole()){return level(key,role)!=='none'}
  function atLeast(key,accepted,role=currentRole()){
    const allowed=Array.isArray(accepted)?accepted:[accepted];return allowed.map(normalize).includes(level(key,role));
  }
  function snapshot(){return structuredClone(matrix)}
  window.KeySuitePermissions={ROLES,DEFAULTS,merge,setMatrix:merge,currentRole,level,can,atLeast,snapshot};
})();
