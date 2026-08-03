(() => {
  'use strict';

  let access=null,users=[],audit=[],editingEmail='',editingUser=null,bound=false;
  let permissionsEditing=false,permissionMatrix=null,permissionHoldTimer=null,permissionHoldTick=null,permissionHoldStarted=0;
  const el=id=>document.getElementById(id);
  const esc=value=>String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const role=()=>String(access?.role||window.KEYSUITE_ACCESS?.role||'viewer').toLowerCase();
  const isOwner=()=>role()==='owner';
  const can=key=>window.KeySuitePermissions?.can?.(key,role())??(isOwner());
  const canManage=()=>can('manage_roles');
  const client=()=>window.KeySuiteAuth?.getClient?.()||null;
  const title=value=>String(value||'').replace(/\b\w/g,ch=>ch.toUpperCase());
  const ROLES=['viewer','dealer','user','admin','owner'];
  const LEVEL_LABELS={none:'No',view:'View',own:'Own',assigned:'Assigned',all:'All',full:'Full'};
  const PERMISSION_ROWS=[
    {key:'key_dashboard',label:'Key button / Key Dashboard',options:['none','full'],className:'permission-key-row'},
    {key:'manage_roles',label:'Assign roles and account status',options:['none','full']},
    {key:'company_pricing',label:'Company & Pricing',options:['none','view','full']},
    {key:'manage_categories',label:'Create / edit pricing categories',options:['none','view','full']},
    {key:'manage_price_list',label:'Maintain Price List',options:['none','view','full']},
    {key:'change_fuel_price',label:'Change Fuel Price',options:['none','full']},
    {key:'view_customers',label:'View customers',options:['none','own','assigned','all']},
    {key:'edit_customers',label:'Add / edit customers',options:['none','own','assigned','all']},
    {key:'customer_assignment',label:'Customer assignment and distance',options:['none','full']},
    {key:'create_quotations',label:'Create quotations',options:['none','full']},
    {key:'view_quotations',label:'View quotations',options:['none','own','assigned','all']},
    {key:'own_profile',label:'Own profile and password',options:['none','full']}
  ];

  function setMessage(id,text,type='error'){const box=el(id);if(!box)return;box.textContent=text||'';box.className=text?`auth-message show ${type}`:'auth-message'}
  function formatDate(value){if(!value)return '-';try{return new Date(value).toLocaleString('en-MY',{year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit'})}catch(_){return value}}
  function currentPermissions(){return permissionMatrix||window.KeySuitePermissions?.snapshot?.()||window.KeySuitePermissions?.DEFAULTS||{}}

  function renderKeyDashboard(){
    const notice=el('keyDashboardNotice'),button=el('openRoleModule');if(!notice||!button)return;
    if(can('key_dashboard')){
      notice.innerHTML=`Signed in as <b>${esc(access?.display_name||access?.email||'approved user')}</b> · <b>${esc(title(role()))}</b>. Key access confirmed.`;
      notice.classList.add('active-customer');
    }else{
      notice.innerHTML='Your role does not currently have Key Dashboard access.';notice.classList.remove('active-customer');
    }
    button.disabled=!canManage();button.style.opacity=canManage()?'1':'.55';
  }

  function renderUsers(){
    const rows=el('roleRows');if(!rows)return;if(!users.length){rows.innerHTML='<tr><td colspan="7" class="muted">No approved users found.</td></tr>';return}
    rows.innerHTML=users.map(user=>{const userRole=String(user.role||'user').toLowerCase(),prefix=String(user.quotation_prefix||'').toUpperCase();return `<tr><td><b>${esc(user.display_name||'-')}</b></td><td>${esc(user.email)}</td><td>${prefix?`<span class="role-badge">${esc(prefix)}</span>`:'<span class="muted">Not assigned</span>'}</td><td><span class="role-badge ${esc(userRole)}">${esc(userRole)}</span></td><td>${user.active?'<span class="badge won">Active</span>':'<span class="badge lost">Inactive</span>'}</td><td>${user.auth_exists?'<span class="auth-state ok">Login ready</span>':'<span class="auth-state missing">Invitation required</span>'}</td><td><div class="role-row-actions"><button class="btn secondary edit-role-user" type="button" data-email="${esc(user.email)}">Edit</button>${!user.auth_exists?`<button class="btn invite-role-user" type="button" data-invite-email="${esc(user.email)}">Invite</button>`:''}</div></td></tr>`}).join('');
    rows.querySelectorAll('.edit-role-user').forEach(button=>button.addEventListener('click',()=>openEdit(button.dataset.email)));
    rows.querySelectorAll('.invite-role-user').forEach(button=>button.addEventListener('click',()=>inviteExisting(button.dataset.inviteEmail,button)));
  }

  function renderAudit(){
    const rows=el('roleAuditRows');if(!rows)return;if(!audit.length){rows.innerHTML='<tr><td colspan="5" class="muted">No role changes recorded yet.</td></tr>';return}
    rows.innerHTML=audit.map(row=>`<tr><td class="role-audit-time">${esc(formatDate(row.changed_at))}</td><td><b>${esc(row.target_display_name||row.target_email)}</b><div class="muted">${esc(row.target_email)}</div></td><td>${row.old_role?`<span class="role-badge ${esc(row.old_role)}">${esc(row.old_role)}</span>${row.old_active===false?' · Inactive':''}`:'New user'}</td><td><span class="role-badge ${esc(row.new_role)}">${esc(row.new_role)}</span>${row.new_active===false?' · Inactive':''}</td><td>${esc(row.changed_by_email||'-')}</td></tr>`).join('');
  }

  async function loadPermissions(showMessage=false){
    const db=client();if(!db)return currentPermissions();
    try{
      const {data,error}=await db.rpc('keysuite_get_role_permissions');if(error)throw error;
      permissionMatrix=window.KeySuitePermissions?.setMatrix?.(data||[])||currentPermissions();
      if(showMessage)setMessage('rolePermissionsMessage','Permissions loaded.','info');
      renderKeyDashboard();
      return permissionMatrix;
    }catch(error){
      console.error(error);
      permissionMatrix=currentPermissions();
      if(showMessage)setMessage('rolePermissionsMessage',`Permissions could not be loaded: ${error.message||error}. Run the V1.24 Supabase migration.`,'error');
      return permissionMatrix;
    }
  }

  async function load(){
    renderKeyDashboard();const notice=el('roleAccessNotice');
    if(!canManage()){if(notice)notice.textContent='Your role is not allowed to manage users.';if(typeof showPage==='function')showPage(can('key_dashboard')?'keyDashboard':'dashboard');return}
    const db=client();if(!db)return;if(notice){notice.textContent='Loading approved users…';notice.classList.remove('active-customer')}
    try{
      const [userResult,auditResult,prefixResult]=await Promise.all([db.rpc('keysuite_list_role_users'),db.rpc('keysuite_list_role_audit',{p_limit:30}),isOwner()?db.rpc('keysuite_list_quotation_prefixes_v225'):Promise.resolve({data:[],error:null})]);
      if(userResult.error)throw userResult.error;if(auditResult.error)throw auditResult.error;if(prefixResult.error)throw prefixResult.error;
      const prefixMap=new Map((prefixResult.data||[]).map(row=>[String(row.email||'').toLowerCase(),String(row.quotation_prefix||'').toUpperCase()]));
      users=(userResult.data||[]).map(user=>({...user,quotation_prefix:prefixMap.get(String(user.email||'').toLowerCase())||''}));audit=auditResult.data||[];
      if(notice){notice.innerHTML=`<b>${users.length}</b> approved user${users.length===1?'':'s'}. New users can receive a secure invitation email to set their own password.`;notice.classList.add('active-customer')}
      renderUsers();renderAudit();
    }catch(error){console.error(error);if(notice)notice.textContent=`Role data could not be loaded: ${error.message||error}.`;users=[];audit=[];renderUsers();renderAudit()}
  }

  function permissionValue(roleName,key){return String(currentPermissions()?.[roleName]?.[key]||window.KeySuitePermissions?.DEFAULTS?.[roleName]?.[key]||'none').toLowerCase()}
  function permissionCell(row,roleName){
    const fixed=roleName==='owner'&&['key_dashboard','manage_roles','own_profile'].includes(row.key);
    const value=fixed?'full':permissionValue(roleName,row.key);
    if(permissionsEditing&&!fixed){
      const options=row.options.map(option=>`<option value="${option}"${value===option?' selected':''}>${LEVEL_LABELS[option]||title(option)}</option>`).join('');
      return `<td><select data-permission-role="${roleName}" data-permission-key="${row.key}">${options}</select></td>`;
    }
    if(permissionsEditing&&fixed)return `<td><span class="permission-fixed">Fixed Full</span></td>`;
    return `<td><span class="permission-value ${esc(value)}">${esc(LEVEL_LABELS[value]||title(value))}</span></td>`;
  }
  function renderPermissions(){
    const body=el('rolePermissionsRows');if(!body)return;
    body.innerHTML=PERMISSION_ROWS.map(row=>`<tr class="${row.className||''}"><td><b>${esc(row.label)}</b></td>${ROLES.map(r=>permissionCell(row,r)).join('')}</tr>`).join('');
    body.closest('table')?.classList.toggle('editing',permissionsEditing);
    el('saveRolePermissions').style.display=permissionsEditing?'inline-flex':'none';
    el('cancelRolePermissions').style.display=permissionsEditing?'inline-flex':'none';
    el('closeRolePermissionsBottom').style.display=permissionsEditing?'none':'inline-flex';
    el('editRolePermissions').style.display=isOwner()&&!permissionsEditing?'inline-flex':'none';
  }

  function stopPermissionHold(reset=true){
    if(permissionHoldTimer)clearTimeout(permissionHoldTimer);if(permissionHoldTick)clearInterval(permissionHoldTick);
    permissionHoldTimer=permissionHoldTick=null;
    const button=el('editRolePermissions');if(button){button.classList.remove('counting');if(reset&&!permissionsEditing)button.textContent='Hold 5s to Edit'}
  }
  function startPermissionHold(event){
    if(!isOwner()||permissionsEditing)return;if(event.pointerType==='mouse'&&event.button!==0)return;
    event.preventDefault();stopPermissionHold(false);permissionHoldStarted=Date.now();const button=el('editRolePermissions');button.classList.add('counting');
    const update=()=>{const left=Math.max(1,5-Math.floor((Date.now()-permissionHoldStarted)/1000));button.textContent=`Edit in ${left}…`};update();permissionHoldTick=setInterval(update,150);
    permissionHoldTimer=setTimeout(()=>{stopPermissionHold(false);permissionsEditing=true;button.textContent='Editing';setMessage('rolePermissionsMessage','Permission editor unlocked. Change the authority levels, then Save Permissions.','info');renderPermissions()},5000);
  }

  function collectPermissionMatrix(){
    const matrix=structuredClone(currentPermissions());
    document.querySelectorAll('[data-permission-role][data-permission-key]').forEach(select=>{
      const r=select.dataset.permissionRole,k=select.dataset.permissionKey;matrix[r]=matrix[r]||{};matrix[r][k]=select.value;
    });
    matrix.owner={...(matrix.owner||{}),key_dashboard:'full',manage_roles:'full',own_profile:'full'};
    return matrix;
  }
  async function savePermissions(){
    if(!isOwner())return;const db=client();if(!db)return;
    const matrix=collectPermissionMatrix(),button=el('saveRolePermissions');button.disabled=true;button.textContent='Saving…';setMessage('rolePermissionsMessage','');
    try{
      const {data,error}=await db.rpc('keysuite_save_role_permissions',{p_matrix:matrix});if(error)throw error;
      permissionMatrix=window.KeySuitePermissions?.setMatrix?.(data||matrix)||matrix;permissionsEditing=false;renderPermissions();renderKeyDashboard();
      window.KeySuiteApp?.applyPermissions?.();window.KeySuiteCategories?.render?.();window.KeySuitePriceList?.render?.();window.KeySuitePricing?.render?.();
      setMessage('rolePermissionsMessage','Role permissions saved. Users receive the new authority after refresh or their next sign-in.','info');
    }catch(error){console.error(error);setMessage('rolePermissionsMessage',`${error.message||error}. Run the V1.24 Supabase migration first.`,'error')}
    finally{button.disabled=false;button.textContent='Save Permissions'}
  }
  function cancelPermissions(){permissionsEditing=false;setMessage('rolePermissionsMessage','Changes cancelled.','info');renderPermissions()}

  function setRoleOptions(selected='user'){const select=el('roleUserRole');if(!select)return;select.value=selected||'user';select.disabled=false}
  function setInviteRow(show,checked=true){const row=el('roleInviteRow');if(row)row.style.display=show?'block':'none';const input=el('roleSendInvite');if(input)input.checked=checked}
  function openAdd(){if(!canManage())return;editingEmail='';editingUser=null;setMessage('roleDialogMessage','');el('roleDialogTitle').textContent='Add User';el('roleUserEmail').readOnly=false;el('roleUserEmail').value='';el('roleUserDisplayName').value='';if(el('roleUserQuotationPrefix')){el('roleUserQuotationPrefix').value='';el('roleUserQuotationPrefix').disabled=!isOwner()}setRoleOptions('user');el('roleUserActive').value='true';setInviteRow(true,true);el('roleUserDialog').showModal()}
  function openEdit(email){const user=users.find(item=>String(item.email).toLowerCase()===String(email).toLowerCase());if(!user)return;editingEmail=user.email;editingUser=user;setMessage('roleDialogMessage','');el('roleDialogTitle').textContent='Edit User Role';el('roleUserEmail').value=user.email;el('roleUserEmail').readOnly=true;el('roleUserDisplayName').value=user.display_name||'';if(el('roleUserQuotationPrefix')){el('roleUserQuotationPrefix').value=user.quotation_prefix||'';el('roleUserQuotationPrefix').disabled=!isOwner()}setRoleOptions(user.role);el('roleUserActive').value=user.active?'true':'false';setInviteRow(!user.auth_exists,!user.auth_exists);el('roleUserDialog').showModal()}
  function closeDialog(){el('roleUserDialog')?.close()}
  async function openPermissions(){if(!canManage())return;permissionsEditing=false;setMessage('rolePermissionsMessage','');await loadPermissions();renderPermissions();el('rolePermissionsDialog')?.showModal()}
  function closePermissions(){stopPermissionHold();permissionsEditing=false;el('rolePermissionsDialog')?.close()}

  async function sendInvitation(user){
    const db=client();if(!db)throw new Error('Supabase is not connected.');
    const redirectTo=`${location.origin}${location.pathname}`;
    const {data,error}=await db.functions.invoke('keysuite-invite-user',{body:{email:user.email,display_name:user.display_name,role:user.role,redirect_to:redirectTo}});
    if(error)throw new Error(`${error.message||error}. Deploy the included Supabase Edge Function “keysuite-invite-user”.`);if(data?.error)throw new Error(data.error);return data||{};
  }
  async function inviteExisting(email,button){const user=users.find(item=>String(item.email).toLowerCase()===String(email).toLowerCase());if(!user)return;const original=button.textContent;button.disabled=true;button.textContent='Sending…';try{await sendInvitation(user);alert(`Invitation sent to ${user.email}. The user can set their own password from the email link.`);await load()}catch(error){console.error(error);alert(`Invitation could not be sent: ${error.message||error}`)}finally{button.disabled=false;button.textContent=original}}

  async function save(event){
    event.preventDefault();if(!canManage())return;
    const email=el('roleUserEmail').value.trim().toLowerCase(),displayName=el('roleUserDisplayName').value.trim(),nextRole=el('roleUserRole').value,active=el('roleUserActive').value==='true',sendInvite=!!el('roleSendInvite')?.checked;
    const quotationPrefix=isOwner()?String(el('roleUserQuotationPrefix')?.value||'').trim().toUpperCase():String(editingUser?.quotation_prefix||'').trim().toUpperCase();
    if(!/^\S+@\S+\.\S+$/.test(email)){setMessage('roleDialogMessage','Enter a valid email address.');return}if(!displayName){setMessage('roleDialogMessage','Display Name is required.');return}
    if(isOwner()&&quotationPrefix&&!/^[A-Z0-9]{1,8}$/.test(quotationPrefix)){setMessage('roleDialogMessage','Quotation Prefix must contain 1 to 8 letters or numbers only.');return}
    const button=el('saveRoleUser');button.disabled=true;button.textContent='Saving…';setMessage('roleDialogMessage','');
    try{
      const result=await client().rpc('keysuite_manage_user_role',{p_email:email,p_display_name:displayName,p_role:nextRole,p_active:active});if(result.error)throw result.error;
      if(isOwner()){button.textContent='Saving prefix…';const prefixResult=await client().rpc('keysuite_assign_quotation_prefix_v225',{p_email:email,p_prefix:quotationPrefix});if(prefixResult.error)throw prefixResult.error;}
      let invitationText='';if(sendInvite&&!editingUser?.auth_exists){button.textContent='Sending invite…';try{const result=await sendInvitation({email,display_name:displayName,role:nextRole});invitationText=result?.status==='already_exists'?' Login account already exists.':' Invitation email sent; the user will set their own password.'}catch(inviteError){invitationText=` Access was saved, but the invitation failed: ${inviteError.message||inviteError}`}}
      setMessage('roleDialogMessage',`${editingEmail?'User access updated.':'User access added.'}${isOwner()?` Prefix ${quotationPrefix||'cleared'}.`:''}${invitationText}`,'info');await load();if(!invitationText.includes('failed'))setTimeout(closeDialog,1100);
    }catch(error){console.error(error);setMessage('roleDialogMessage',error.message||'The user role could not be saved.')}finally{button.disabled=false;button.textContent='Save User'}
  }

  function bind(){
    if(bound)return;bound=true;
    el('openRoleModule')?.addEventListener('click',()=>{if(!canManage()){alert('Your role is not allowed to open Role management.');return}if(typeof showPage==='function')showPage('roleManagement')});
    el('viewRolePermissions')?.addEventListener('click',openPermissions);el('closeRolePermissions')?.addEventListener('click',closePermissions);el('closeRolePermissionsBottom')?.addEventListener('click',closePermissions);
    el('editRolePermissions')?.addEventListener('pointerdown',startPermissionHold);['pointerup','pointerleave','pointercancel'].forEach(name=>el('editRolePermissions')?.addEventListener(name,()=>stopPermissionHold()));el('editRolePermissions')?.addEventListener('contextmenu',e=>e.preventDefault());
    el('saveRolePermissions')?.addEventListener('click',savePermissions);el('cancelRolePermissions')?.addEventListener('click',cancelPermissions);
    el('roleUserQuotationPrefix')?.addEventListener('input',event=>{event.target.value=String(event.target.value||'').toUpperCase().replace(/[^A-Z0-9]/g,'').slice(0,8)});
    el('addRoleUser')?.addEventListener('click',openAdd);el('reloadRoles')?.addEventListener('click',load);el('roleUserForm')?.addEventListener('submit',save);el('closeRoleDialog')?.addEventListener('click',closeDialog);el('cancelRoleDialog')?.addEventListener('click',closeDialog);
  }
  function init(userAccess){access=userAccess||access;bind();renderKeyDashboard()}
  function pageShown(id){if(id==='keyDashboard')renderKeyDashboard();if(id==='roleManagement')load()}
  window.addEventListener('keysuite-permissions-changed',renderKeyDashboard);
  window.KeySuiteRoles={init,pageShown,load,loadPermissions};
})();
