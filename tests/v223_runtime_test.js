'use strict';
let routed=null;
globalThis.KEYSUITE_ACCESS={role:'owner'};
globalThis.KEYSUITE_SECURE_DATA={categories:[{id:'cat-1',name:'Default',productRules:{MOTOR:{margin:.2,normal:0,rare:0,transport:0}}}]};
globalThis.KeySuiteApp={
  ensureQuotationPricingContext:()=>true,
  getPricingCustomer:()=>({id:'cust-1',pricingCategoryId:'cat-1'}),
  getSelectedCustomer:()=>({id:'cust-1',pricingCategoryId:'cat-1'})
};
globalThis.KeySuitePricing={calculatePrice:()=>({finalPrice:125,sourceCurrency:'MYR',sourcePrice:100,multiplier:1})};
globalThis.KeySuiteAssembly={addItem:(item,route)=>{routed={item,route}}};
require('../v223-runtime.js');
const api=globalThis.KeySuiteV223;
function equal(actual,expected,label){if(JSON.stringify(actual)!==JSON.stringify(expected))throw new Error(`${label}: expected ${JSON.stringify(expected)}, received ${JSON.stringify(actual)}`)}
equal(api.parseMotorModel('BM20-2').description,'20HP 2Pole IE1 Motor','IE1 parser');
equal(api.parseMotorModel('2BM20-4').efficiencyClass,'IE2','IE2 parser');
equal(api.parseMotorModel('3BM50-5').description,'50HP 5Pole IE3 Motor','custom pole parser');
equal(api.parseMotorModel('4BM0.75-8').description,'0.75HP 8Pole IE4 Motor','IE4 decimal HP');
equal(api.parseMotorModel('5BM600-6').efficiencyClass,'IE5','IE5 parser');
equal(api.parseMotorModel('6BM20-2'),null,'invalid prefix');
equal(api.buildMotorModel('IE2',20,2).model,'2BM20-2','model builder');
api.addProduct({id:'m1',model:'3BM50-4',efficiency_class:'IE3',hp:50,pole:4,description:'50HP 4Pole IE3 Motor',price_myr:100,price_usd:0,price_rmb:0,rarity:'common'},'assembly');
equal(routed.route,'pumpset','assembly route');
equal(routed.item.assemblySection,'motor','assembly section');
equal(routed.item.assemblyLevel,'PUMPSET_COMPONENT','assembly level');
console.log('PASS - V2.23 motor parser, builder, and Pumpset > Motor routing');
