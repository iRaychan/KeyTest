(function(root,factory){
  var api=factory();
  if(typeof module==='object'&&module.exports){module.exports=api;}
  else{root.ESCore=api;}
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';

  var STANDARD_MOTORS=[
    {kw:0.37,hp:0.5},{kw:0.55,hp:0.75},{kw:0.75,hp:1},{kw:1.1,hp:1.5},
    {kw:1.5,hp:2},{kw:2.2,hp:3},{kw:3,hp:4},{kw:4,hp:5.5},
    {kw:5.5,hp:7.5},{kw:7.5,hp:10},{kw:11,hp:15},{kw:15,hp:20},
    {kw:18.5,hp:25},{kw:22,hp:30},{kw:30,hp:40},{kw:37,hp:50},
    {kw:45,hp:60},{kw:55,hp:75},{kw:75,hp:100},{kw:90,hp:125},
    {kw:110,hp:150},{kw:132,hp:175},{kw:160,hp:200},{kw:200,hp:250},
    {kw:250,hp:300},{kw:315,hp:400},{kw:355,hp:450},{kw:400,hp:500},
    {kw:450,hp:600}
  ];

  function finite(v){return typeof v==='number'&&Number.isFinite(v);}
  function round(v,d){var p=Math.pow(10,d||0);return Math.round(v*p)/p;}
  function uniqueNumbers(values){
    var out=[];
    (values||[]).forEach(function(v){if(finite(v)&&out.indexOf(v)<0)out.push(v);});
    return out.sort(function(a,b){return a-b;});
  }
  function dedupeXY(xs,ys){
    var grouped=new Map();
    (xs||[]).forEach(function(x,i){
      var y=(ys||[])[i];
      if(!finite(x)||!finite(y))return;
      x=Number(x);y=Number(y);
      if(!grouped.has(x))grouped.set(x,[]);
      grouped.get(x).push(y);
    });
    return Array.from(grouped.entries()).map(function(entry){
      var a=entry[1];
      return [entry[0],a.reduce(function(sum,v){return sum+v;},0)/a.length];
    }).sort(function(a,b){return a[0]-b[0];});
  }
  function interpolate(xs,ys,x,clamp){
    var pts=dedupeXY(xs,ys);
    if(!pts.length||!finite(x))return null;
    if(x<pts[0][0])return clamp?pts[0][1]:null;
    if(x>pts[pts.length-1][0])return clamp?pts[pts.length-1][1]:null;
    for(var i=0;i<pts.length;i++){
      if(Math.abs(x-pts[i][0])<1e-9)return pts[i][1];
      if(i+1<pts.length&&x>=pts[i][0]&&x<=pts[i+1][0]){
        var x1=pts[i][0],y1=pts[i][1],x2=pts[i+1][0],y2=pts[i+1][1];
        if(x2===x1)return y2;
        return y1+(x-x1)/(x2-x1)*(y2-y1);
      }
    }
    return pts[pts.length-1][1];
  }

  function solveLinear(A,b){
    A=A.map(function(row){return row.slice();});b=b.slice();
    var n=A.length;
    for(var i=0;i<n;i++){
      var pivot=i;
      for(var j=i+1;j<n;j++)if(Math.abs(A[j][i])>Math.abs(A[pivot][i]))pivot=j;
      var tr=A[i];A[i]=A[pivot];A[pivot]=tr;
      var tb=b[i];b[i]=b[pivot];b[pivot]=tb;
      var pv=Math.abs(A[i][i])<1e-14?(A[i][i]<0?-1e-14:1e-14):A[i][i];
      for(var k=i;k<n;k++)A[i][k]/=pv;
      b[i]/=pv;
      for(var r=0;r<n;r++){
        if(r===i)continue;
        var f=A[r][i];
        if(Math.abs(f)<1e-18)continue;
        for(var c=i;c<n;c++)A[r][c]-=f*A[i][c];
        b[r]-=f*b[i];
      }
    }
    return b;
  }
  function polyFit(xs,ys,order){
    var pts=dedupeXY(xs,ys);
    if(!pts.length)return null;
    var degree=Math.max(0,Math.min(Number(order)||0,pts.length-1));
    var min=pts[0][0],max=pts[pts.length-1][0],center=(min+max)/2;
    var scale=Math.max((max-min)/2,1);
    var ts=pts.map(function(p){return (p[0]-center)/scale;});
    var vs=pts.map(function(p){return p[1];});
    var n=degree+1,A=Array.from({length:n},function(){return Array(n).fill(0);}),b=Array(n).fill(0);
    for(var r=0;r<n;r++){
      for(var c=0;c<n;c++){
        var sum=0;
        for(var i=0;i<ts.length;i++)sum+=Math.pow(ts[i],r+c);
        A[r][c]=sum;
      }
      var sb=0;
      for(var i2=0;i2<ts.length;i2++)sb+=vs[i2]*Math.pow(ts[i2],r);
      b[r]=sb;
    }
    return {coeff:solveLinear(A,b),degree:degree,min:min,max:max,center:center,scale:scale,points:pts};
  }
  function polyEval(fit,x,clamp){
    if(!fit||!finite(x))return null;
    if(x<fit.min)return clamp?polyEval(fit,fit.min,false):null;
    if(x>fit.max)return clamp?polyEval(fit,fit.max,false):null;
    var t=(x-fit.center)/fit.scale,sum=0,pow=1;
    for(var i=0;i<fit.coeff.length;i++){sum+=fit.coeff[i]*pow;pow*=t;}
    return sum;
  }
  var fitCache=typeof WeakMap!=='undefined'?new WeakMap():null;
  function pumpFits(pump){
    if(fitCache&&fitCache.has(pump))return fitCache.get(pump);
    var out={
      head:polyFit(pump.flow_lps,pump.head_m,2),
      npsh:polyFit(pump.flow_lps,pump.npsh_m,3),
      efficiency:{}
    };
    (pump.impellers||[]).forEach(function(d,i){
      var label=String.fromCharCode(65+i);
      var curve=pump.efficiency&&pump.efficiency[label];
      if(curve)out.efficiency[label]=polyFit(pump.flow_lps,curve,6);
    });
    if(fitCache)fitCache.set(pump,out);
    return out;
  }
  function dmax(pump){return Math.max.apply(null,uniqueNumbers(pump.impellers));}
  function dmin(pump){return Math.min.apply(null,uniqueNumbers(pump.impellers));}

  function efficiencyAt(pump,diameter,qReference){
    var grouped={},fits=pumpFits(pump);
    (pump.impellers||[]).forEach(function(d,i){
      if(!finite(d))return;
      var label=String.fromCharCode(65+i);
      var eta=polyEval(fits.efficiency[label],qReference,false);
      if(!finite(eta))return;
      eta=Math.max(0,Math.min(100,eta));
      if(!grouped[d])grouped[d]=[];
      grouped[d].push(eta);
    });
    var pts=Object.keys(grouped).map(function(k){
      var a=grouped[k];
      return [Number(k),a.reduce(function(s,v){return s+v;},0)/a.length];
    }).sort(function(a,b){return a[0]-b[0];});
    if(!pts.length)return null;
    if(diameter<=pts[0][0])return pts[0][1];
    if(diameter>=pts[pts.length-1][0])return pts[pts.length-1][1];
    for(var i=0;i+1<pts.length;i++){
      var p1=pts[i],p2=pts[i+1];
      if(diameter>=p1[0]&&diameter<=p2[0]){
        return p1[1]+(diameter-p1[0])/(p2[0]-p1[0])*(p2[1]-p1[1]);
      }
    }
    return null;
  }

  function performance(pump,diameter,flowLps,speedRatio){
    speedRatio=finite(speedRatio)?speedRatio:1;
    if(!pump||!finite(diameter)||!finite(flowLps)||diameter<=0||speedRatio<=0)return null;
    var maxD=dmax(pump);
    var qRef=flowLps*(maxD/diameter)/speedRatio;
    var fits=pumpFits(pump);
    var hRef=polyEval(fits.head,qRef,false);
    if(!finite(hRef))return null;
    hRef=Math.max(0,hRef);
    var exponent=finite(pump.multiplier)?pump.multiplier:2;
    var head=hRef*Math.pow(diameter/maxD,exponent)*Math.pow(speedRatio,2);
    var eta=efficiencyAt(pump,diameter,qRef);
    var nRef=polyEval(fits.npsh,qRef,false);
    var npsh=finite(nRef)?Math.max(0,nRef)*Math.pow(speedRatio,2):null;
    var shaftKw=(finite(eta)&&eta>0)?9.80665*(flowLps/1000)*head/(eta/100):null;
    return {
      referenceFlowLps:qRef,
      flowLps:flowLps,
      flowM3h:flowLps*3.6,
      headM:head,
      efficiencyPct:eta,
      npshrM:npsh,
      hydraulicKw:9.80665*(flowLps/1000)*head,
      shaftKw:shaftKw,
      bhp:finite(shaftKw)?shaftKw/0.745699872:null,
      speedRatio:speedRatio,
      rpm:pump.rpm*speedRatio,
      frequencyHz:50*speedRatio
    };
  }

  function solveTheoreticalDiameter(pump,flowLps,targetHead){
    var lo=dmin(pump),hi=dmax(pump);
    var maxPerf=performance(pump,hi,flowLps,1);
    if(!maxPerf||maxPerf.headM+1e-8<targetHead)return null;
    var minPerf=performance(pump,lo,flowLps,1);
    if(minPerf&&minPerf.headM>=targetHead)return lo;
    for(var i=0;i<90;i++){
      var mid=(lo+hi)/2;
      var p=performance(pump,mid,flowLps,1);
      if(!p||p.headM<targetHead)lo=mid;else hi=mid;
    }
    return hi;
  }

  function roundImpeller(pump,theoretical,flowLps,targetHead){
    var maxD=dmax(pump),minD=dmin(pump),selected;
    if(theoretical>=maxD-1e-8){
      selected=maxD;
    }else{
      selected=Math.ceil(theoretical/5-1e-10)*5;
      selected=Math.max(Math.ceil(minD/5)*5,selected);
      if(selected>maxD)selected=maxD;
    }
    return {diameterMm:selected,performance:performance(pump,selected,flowLps,1)};
  }

  function solveSpeedRatio(pump,flowLps,targetHead){
    var maxD=dmax(pump);
    var maxFlow=Math.max.apply(null,uniqueNumbers(pump.flow_lps));
    var low=Math.max(0.2,flowLps/maxFlow);
    var high=1;
    var full=performance(pump,maxD,flowLps,1);
    if(!full||full.headM+1e-8<targetHead)return null;
    var lowPerf=performance(pump,maxD,flowLps,low);
    if(lowPerf&&lowPerf.headM>=targetHead)return low;
    for(var i=0;i<90;i++){
      var mid=(low+high)/2;
      var p=performance(pump,maxD,flowLps,mid);
      if(!p||p.headM<targetHead)low=mid;else high=mid;
    }
    return high;
  }

  function curvePoints(pump,diameter,speedRatio,samples){
    var maxD=dmax(pump),fits=pumpFits(pump),out=[];
    speedRatio=finite(speedRatio)?speedRatio:1;
    var minQ=fits.head?fits.head.min:Math.min.apply(null,uniqueNumbers(pump.flow_lps));
    var maxQ=fits.head?fits.head.max:Math.max.apply(null,uniqueNumbers(pump.flow_lps));
    if(samples){
      var count=Math.max(2,Number(samples)||181);
      for(var i=0;i<count;i++){
        var qRef=minQ+(maxQ-minQ)*(i/(count-1));
        var actualQ=qRef*(diameter/maxD)*speedRatio;
        var p=performance(pump,diameter,actualQ,speedRatio);
        if(p){p.referenceFlowLps=qRef;out.push(p);}
      }
      return out;
    }
    return uniqueNumbers(pump.flow_lps).map(function(qRef){
      var actualQ=qRef*(diameter/maxD)*speedRatio;
      var p=performance(pump,diameter,actualQ,speedRatio);
      if(!p)return null;
      p.referenceFlowLps=qRef;
      return p;
    }).filter(Boolean);
  }

  function bepData(pump,diameter,speedRatio){
    var points=curvePoints(pump,diameter,speedRatio,241).filter(function(p){
      return finite(p.efficiencyPct)&&p.efficiencyPct>0&&finite(p.shaftKw);
    });
    if(!points.length)return null;
    var bep=points.reduce(function(best,p){
      return !best||p.efficiencyPct>best.efficiencyPct?p:best;
    },null);
    var end=points.reduce(function(best,p){
      return !best||p.flowLps>best.flowLps?p:best;
    },null);
    return {bep:bep,end:end,points:points};
  }

  function selectStandardMotor(requiredKw){
    for(var i=0;i<STANDARD_MOTORS.length;i++){
      if(STANDARD_MOTORS[i].kw+1e-9>=requiredKw)return STANDARD_MOTORS[i];
    }
    return STANDARD_MOTORS[STANDARD_MOTORS.length-1];
  }

  function sizeMotor(pump,diameter,speedRatio,dutyPerformance){
    var data=bepData(pump,diameter,speedRatio);
    if(!data||!finite(dutyPerformance.shaftKw))return null;
    var ratio=dutyPerformance.flowLps/data.bep.flowLps;
    var requiredKw,factor,rule;
    if(ratio<0.82){
      factor=1.30;requiredKw=dutyPerformance.shaftKw*factor;
      rule='Duty flow is more than 18% below BEP: BHP × 1.30';
    }else if(ratio<=1.13){
      factor=1.20;requiredKw=dutyPerformance.shaftKw*factor;
      rule='Duty flow is within -18% / +13% of BEP: BHP × 1.20';
    }else if(dutyPerformance.shaftKw*1.10>=data.end.shaftKw){
      factor=1.10;requiredKw=dutyPerformance.shaftKw*factor;
      rule='Duty is above +13% of BEP and BHP × 1.10 covers end-curve BHP';
    }else{
      factor=null;
      requiredKw=Math.max(dutyPerformance.shaftKw*1.15,data.end.shaftKw);
      rule='Duty is above +13% of BEP: use higher of duty BHP × 1.15 or end-curve BHP';
    }
    var motor=selectStandardMotor(requiredKw);
    return {
      bepFlowLps:data.bep.flowLps,
      bepHeadM:data.bep.headM,
      bepEfficiencyPct:data.bep.efficiencyPct,
      flowRatio:ratio,
      endCurveFlowLps:data.end.flowLps,
      endCurveShaftKw:data.end.shaftKw,
      dutyShaftKw:dutyPerformance.shaftKw,
      sizingFactor:factor,
      sizingRule:rule,
      requiredKw:requiredKw,
      motorKw:motor.kw,
      motorHp:motor.hp
    };
  }

  function buildResult(pump,mode,flowLps,targetHead,options){
    options=options||{};
    var maxD=dmax(pump),theoretical,selectedD,speedRatio=1,exactHz=50,selectedHz=50,perf;
    if(mode==='vfd'){
      theoretical=solveSpeedRatio(pump,flowLps,targetHead);
      if(!finite(theoretical))return null;
      exactHz=theoretical*50;
      selectedHz=Math.ceil(exactHz-1e-10);
      if(selectedHz>50)return null;
      speedRatio=selectedHz/50;
      selectedD=maxD;
      perf=performance(pump,selectedD,flowLps,speedRatio);
    }else{
      theoretical=solveTheoreticalDiameter(pump,flowLps,targetHead);
      if(!finite(theoretical))return null;
      var rounded=roundImpeller(pump,theoretical,flowLps,targetHead);
      selectedD=rounded.diameterMm;
      perf=rounded.performance;
    }
    if(!perf||perf.headM+1e-7<targetHead||!finite(perf.efficiencyPct)||perf.efficiencyPct<=0)return null;
    var motor=sizeMotor(pump,selectedD,speedRatio,perf);
    if(!motor)return null;
    var insidePreferred=motor.flowRatio>=0.82&&motor.flowRatio<=1.13;
    var score=(insidePreferred?1000:0)+perf.efficiencyPct-Math.abs(motor.flowRatio-1)*10-motor.motorKw*0.001;
    return {
      id:pump.id+'-'+mode,
      pump:pump,
      mode:mode,
      requestedFlowLps:flowLps,
      requestedHeadM:targetHead,
      theoreticalDiameterMm:mode==='trim'?theoretical:null,
      impellerMm:selectedD,
      exactFrequencyHz:mode==='vfd'?exactHz:50,
      frequencyHz:mode==='vfd'?selectedHz:50,
      speedRatio:speedRatio,
      performance:perf,
      motor:motor,
      insidePreferredRange:insidePreferred,
      score:score
    };
  }

  function catalogModelParts(model){
    var m=String(model||'').trim().match(/^(\d+)\s*-\s*(\d+)([A-Za-z]*)$/);
    if(!m)return {a:Number.MAX_SAFE_INTEGER,b:Number.MAX_SAFE_INTEGER,suffix:String(model||'').toUpperCase()};
    return {a:Number(m[1]),b:Number(m[2]),suffix:(m[3]||'').toUpperCase()};
  }
  function catalogModelCompare(a,b){
    var ma=catalogModelParts(a&&a.pump?a.pump.model:a),mb=catalogModelParts(b&&b.pump?b.pump.model:b);
    if(ma.a!==mb.a)return ma.a-mb.a;
    if(ma.b!==mb.b)return ma.b-mb.b;
    var rank={"":0,H:1,G:2},ra=Object.prototype.hasOwnProperty.call(rank,ma.suffix)?rank[ma.suffix]:10,rb=Object.prototype.hasOwnProperty.call(rank,mb.suffix)?rank[mb.suffix]:10;
    if(ra!==rb)return ra-rb;
    return ma.suffix.localeCompare(mb.suffix);
  }
  function selectionEfficiency(result){
    if(result&&result.dutyPoints&&result.dutyPoints.length)return Number(result.dutyPoints[0].performance&&result.dutyPoints[0].performance.efficiencyPct)||0;
    return Number(result&&result.performance&&result.performance.efficiencyPct)||0;
  }
  function selectionImpellerGap(result){
    return result&&result.pump?Math.max(0,dmax(result.pump)-Number(result.impellerMm||0)):Number.MAX_SAFE_INTEGER;
  }
  function selectionBepRatio(result){
    if(result&&result.dutyPoints&&result.dutyPoints.length&&result.dutyPoints[0].motor)return Number(result.dutyPoints[0].motor.flowRatio);
    return Number(result&&result.motor&&result.motor.flowRatio);
  }
  // KeyES recommendation priority:
  // 1) highest duty-point efficiency, 2) impeller nearest full/max diameter,
  // 3) duty flow within +/-10% of BEP, then closest to BEP.
  function compareSelectionPriority(a,b){
    var ea=selectionEfficiency(a),eb=selectionEfficiency(b);
    if(Math.abs(ea-eb)>1e-9)return eb-ea;
    var ga=selectionImpellerGap(a),gb=selectionImpellerGap(b);
    if(Math.abs(ga-gb)>1e-9)return ga-gb;
    var ra=selectionBepRatio(a),rb=selectionBepRatio(b),da=finite(ra)?Math.abs(ra-1):Infinity,db=finite(rb)?Math.abs(rb-1):Infinity;
    var wa=da<=0.10+1e-12,wb=db<=0.10+1e-12;
    if(wa!==wb)return wa?-1:1;
    if(Math.abs(da-db)>1e-9)return da-db;
    return catalogModelCompare(a,b);
  }

  function selectPumps(db,options){
    options=options||{};
    var flow=Number(options.flowLps),head=Number(options.headM);
    var mode=options.mode==='vfd'?'vfd':'trim';
    var rpm=Number(options.rpm||0);
    if(!(flow>0&&head>0))return [];
    return (db.pumps||[]).filter(function(p){
      return !rpm||p.rpm===rpm;
    }).map(function(p){
      try{return buildResult(p,mode,flow,head,options);}catch(e){return null;}
    }).filter(Boolean).sort(compareSelectionPriority);
  }


  function normalizeDutyPoints(duties){
    return (duties||[]).map(function(d,i){
      var total=Number(d.totalFlowLps!=null?d.totalFlowLps:d.flowLps);
      var head=Number(d.headM);
      var pumps=Math.max(1,Math.min(6,Math.round(Number(d.pumps)||1)));
      if(!(total>0&&head>0))return null;
      return {index:i,label:d.label||('D'+(i+1)),totalFlowLps:total,headM:head,pumps:pumps,perPumpFlowLps:total/pumps};
    }).filter(Boolean).slice(0,6);
  }

  function combineMotorChecks(checks){
    checks=(checks||[]).filter(Boolean);
    if(!checks.length)return null;
    var critical=0;
    for(var i=1;i<checks.length;i++)if(checks[i].requiredKw>checks[critical].requiredKw)critical=i;
    var base=Object.assign({},checks[critical]);
    var motor=selectStandardMotor(Math.max.apply(null,checks.map(function(x){return x.requiredKw;})));
    base.requiredKw=Math.max.apply(null,checks.map(function(x){return x.requiredKw;}));
    base.motorKw=motor.kw;base.motorHp=motor.hp;base.criticalDutyIndex=critical;base.dutyChecks=checks;
    return base;
  }

  function roundImpellerForDuties(pump,theoretical,duties){
    var maxD=dmax(pump),minD=dmin(pump),selected;
    if(theoretical>=maxD-1e-8)selected=maxD;
    else{
      // Automatic duty sizing always rounds upward to the next 5 mm.
      selected=Math.ceil(theoretical/5-1e-10)*5;
      selected=Math.max(Math.ceil(minD/5)*5,selected);
      if(selected>maxD)selected=maxD;
    }
    function meets(d){var p=performance(pump,selected,d.perPumpFlowLps,1);return p&&p.headM+1e-8>=d.headM;}
    while(selected<maxD&&!duties.every(meets))selected=Math.min(maxD,selected+5);
    if(!duties.every(meets))return null;
    return selected;
  }

  function buildMultiResult(pump,mode,duties,options){
    options=options||{};duties=normalizeDutyPoints(duties);
    if(!duties.length)return null;
    var maxD=dmax(pump),selectedD=maxD,dutyResults=[],theoretical=null;
    if(mode==='flex'){
      selectedD=maxD;
      for(var f=0;f<duties.length;f++){
        var fd=duties[f],fp=performance(pump,selectedD,fd.perPumpFlowLps,1);
        if(!fp||!finite(fp.efficiencyPct)||fp.efficiencyPct<=0||fp.headM+1e-7<fd.headM)return null;
        var fmc=sizeMotor(pump,selectedD,1,fp);if(!fmc)return null;
        dutyResults.push(Object.assign({},fd,{impellerMm:selectedD,exactFrequencyHz:50,frequencyHz:50,speedRatio:1,performance:fp,motor:fmc,meetsHead:true}));
      }
    }else if(mode==='vfd'){
      for(var i=0;i<duties.length;i++){
        var d=duties[i],ratio=solveSpeedRatio(pump,d.perPumpFlowLps,d.headM);
        if(!finite(ratio))return null;
        var exactHz=ratio*50,selectedHz=Math.ceil(exactHz-1e-10);
        if(selectedHz>50)return null;
        var speedRatio=selectedHz/50,perf=performance(pump,maxD,d.perPumpFlowLps,speedRatio);
        if(!perf||perf.headM+1e-7<d.headM||!finite(perf.efficiencyPct)||perf.efficiencyPct<=0)return null;
        var motorCheck=sizeMotor(pump,maxD,speedRatio,perf);if(!motorCheck)return null;
        dutyResults.push(Object.assign({},d,{impellerMm:maxD,exactFrequencyHz:exactHz,frequencyHz:selectedHz,speedRatio:speedRatio,performance:perf,motor:motorCheck}));
      }
    }else{
      var required=[];
      for(var j=0;j<duties.length;j++){
        var th=solveTheoreticalDiameter(pump,duties[j].perPumpFlowLps,duties[j].headM);
        if(!finite(th))return null;required.push(th);
      }
      theoretical=Math.max.apply(null,required);
      selectedD=roundImpellerForDuties(pump,theoretical,duties);if(!finite(selectedD))return null;
      for(var k=0;k<duties.length;k++){
        var dd=duties[k],pp=performance(pump,selectedD,dd.perPumpFlowLps,1);
        if(!pp||pp.headM+1e-7<dd.headM||!finite(pp.efficiencyPct)||pp.efficiencyPct<=0)return null;
        var mc=sizeMotor(pump,selectedD,1,pp);if(!mc)return null;
        dutyResults.push(Object.assign({},dd,{impellerMm:selectedD,theoreticalDiameterMm:required[k],exactFrequencyHz:50,frequencyHz:50,speedRatio:1,performance:pp,motor:mc}));
      }
    }
    var combined=combineMotorChecks(dutyResults.map(function(x){return x.motor;}));if(!combined)return null;
    var primary=dutyResults[0],allPreferred=dutyResults.every(function(x){return x.motor.flowRatio>=0.82&&x.motor.flowRatio<=1.13;});
    var avgEta=dutyResults.reduce(function(s,x){return s+x.performance.efficiencyPct;},0)/dutyResults.length;
    var avgDev=dutyResults.reduce(function(s,x){return s+Math.abs(x.motor.flowRatio-1);},0)/dutyResults.length;
    var score=(allPreferred?1000:0)+avgEta-avgDev*10-combined.motorKw*0.001;
    return {
      id:pump.id+'-'+mode+'-multi',pump:pump,mode:mode,
      requestedFlowLps:primary.totalFlowLps,requestedHeadM:primary.headM,requestedTotalFlowLps:primary.totalFlowLps,
      theoreticalDiameterMm:mode==='trim'?theoretical:null,impellerMm:(mode==='trim'||mode==='flex')?selectedD:maxD,
      exactFrequencyHz:primary.exactFrequencyHz,frequencyHz:primary.frequencyHz,speedRatio:primary.speedRatio,
      performance:primary.performance,motor:combined,insidePreferredRange:allPreferred,score:score,
      dutyPoints:dutyResults,criticalDutyIndex:combined.criticalDutyIndex
    };
  }

  function selectPumpsMulti(db,options){
    options=options||{};var mode=options.mode==='vfd'?'vfd':options.mode==='flex'?'flex':'trim',rpm=Number(options.rpm||0);
    var duties=normalizeDutyPoints(options.dutyPoints||[]);if(!duties.length)return [];
    return (db.pumps||[]).filter(function(p){return !rpm||p.rpm===rpm;}).map(function(p){
      try{return buildMultiResult(p,mode,duties,options);}catch(e){return null;}
    }).filter(Boolean).sort(compareSelectionPriority);
  }


  function applyFlexibleSetting(result,diameterMm,frequencyHz){
    if(!result||!result.pump)return null;
    var pump=result.pump,maxD=dmax(pump),minD=dmin(pump);
    diameterMm=Number(diameterMm);frequencyHz=Number(frequencyHz);
    if(!finite(diameterMm))diameterMm=maxD;
    if(!finite(frequencyHz))frequencyHz=50;
    // Manual impeller is an exact whole-mm diameter. Frequency is an exact 0.1 Hz setting.
    diameterMm=Math.round(Math.max(minD,Math.min(maxD,diameterMm)));
    frequencyHz=Math.round(frequencyHz*10)/10;
    if(!(frequencyHz>0))return null;
    var speedRatio=frequencyHz/50,duties=normalizeDutyPoints(result.dutyPoints||[]),dutyResults=[];
    if(!duties.length)return null;
    for(var i=0;i<duties.length;i++){
      var d=duties[i],perf=performance(pump,diameterMm,d.perPumpFlowLps,speedRatio);
      if(!perf||!finite(perf.efficiencyPct)||perf.efficiencyPct<=0)return null;
      var mc=sizeMotor(pump,diameterMm,speedRatio,perf);if(!mc)return null;
      dutyResults.push(Object.assign({},d,{impellerMm:diameterMm,exactFrequencyHz:frequencyHz,frequencyHz:frequencyHz,speedRatio:speedRatio,performance:perf,motor:mc,meetsHead:perf.headM+1e-7>=d.headM}));
    }
    var combined=combineMotorChecks(dutyResults.map(function(x){return x.motor;}));if(!combined)return null;
    var primary=dutyResults[0],allPreferred=dutyResults.every(function(x){return x.motor.flowRatio>=0.82&&x.motor.flowRatio<=1.13;}),meetsAll=dutyResults.every(function(x){return x.meetsHead;});
    var avgEta=dutyResults.reduce(function(sum,x){return sum+x.performance.efficiencyPct;},0)/dutyResults.length;
    var avgDev=dutyResults.reduce(function(sum,x){return sum+Math.abs(x.motor.flowRatio-1);},0)/dutyResults.length;
    return Object.assign({},result,{mode:'flex',id:pump.id+'-flex-manual',theoreticalDiameterMm:null,impellerMm:diameterMm,exactFrequencyHz:frequencyHz,frequencyHz:frequencyHz,speedRatio:speedRatio,performance:primary.performance,motor:combined,insidePreferredRange:allPreferred,meetsAllDuties:meetsAll,score:(allPreferred?1000:0)+avgEta-avgDev*10-combined.motorKw*0.001,dutyPoints:dutyResults,criticalDutyIndex:combined.criticalDutyIndex});
  }

  function systemCurveStaticDuty(staticHeadM,designFlowLps,designHeadM){
    staticHeadM=Number(staticHeadM);designFlowLps=Number(designFlowLps);designHeadM=Number(designHeadM);
    if(!(finite(staticHeadM)&&designFlowLps>0&&finite(designHeadM)&&designHeadM>=staticHeadM))return null;
    // User-specified method: derive K in ft/(US gpm)^2 from the required duty point.
    var mToFt=1/0.3048,usgpmPerLps=15.850323141489;
    var staticHeadFt=staticHeadM*mToFt,designHeadFt=designHeadM*mToFt,designFlowUsGpm=designFlowLps*usgpmPerLps;
    var kUsGpm2=(designHeadFt-staticHeadFt)/(designFlowUsGpm*designFlowUsGpm);
    // Retain equivalent L/s coefficient for compatibility and diagnostics.
    var k=(designHeadM-staticHeadM)/(designFlowLps*designFlowLps);
    return {staticHeadM:staticHeadM,staticHeadFt:staticHeadFt,k:k,kUsGpm2:kUsGpm2,designFlowLps:designFlowLps,designHeadM:designHeadM,method:'static-duty-usgpm'};
  }
  function systemCurveTwoPoints(q1,h1,q2,h2){
    q1=Number(q1);h1=Number(h1);q2=Number(q2);h2=Number(h2);
    var den=q2*q2-q1*q1;if(!(q1>=0&&q2>=0&&finite(h1)&&finite(h2)&&Math.abs(den)>1e-12))return null;
    var k=(h2-h1)/den,staticHeadM=h1-k*q1*q1;
    if(!finite(k)||!finite(staticHeadM)||k<0)return null;
    return {staticHeadM:staticHeadM,k:k,method:'two-points'};
  }
  function systemHead(curve,flowLps){
    if(!curve)return null;
    flowLps=Number(flowLps);
    if(finite(curve.kUsGpm2)&&finite(curve.staticHeadFt)){
      var qUsGpm=flowLps*15.850323141489;
      return (curve.staticHeadFt+curve.kUsGpm2*qUsGpm*qUsGpm)*0.3048;
    }
    return finite(curve.k)?curve.staticHeadM+curve.k*flowLps*flowLps:null;
  }
  function orificeCurveKnown(flowLps,headLossM){
    flowLps=Number(flowLps);headLossM=Number(headLossM);
    if(!(flowLps>0&&headLossM>=0))return null;
    return {k:headLossM/(flowLps*flowLps),method:'known-point'};
  }
  function orificeCurvePhysical(diameterMm,cd){
    diameterMm=Number(diameterMm);cd=Number(cd);
    if(!(diameterMm>0&&cd>0))return null;
    var area=Math.PI*Math.pow(diameterMm/1000,2)/4,g=9.80665;
    var k=Math.pow((1/1000)/(cd*area),2)/(2*g);
    return {k:k,diameterMm:diameterMm,cd:cd,method:'physical'};
  }
  // KeyES retained restriction/orifice formula supplied by the user.
  // Input flow for the formula is US gpm; output is converted from ft to metres.
  function orificeCurveKFactor(orificeSizeMm,pumpDischargeMm,kFactor){
    orificeSizeMm=Number(orificeSizeMm);pumpDischargeMm=Number(pumpDischargeMm);kFactor=Number(kFactor);
    if(!(orificeSizeMm>0&&pumpDischargeMm>0&&kFactor>0&&orificeSizeMm<pumpDischargeMm))return null;
    var ratio=orificeSizeMm/pumpDischargeMm;
    var correction=orificeSizeMm>pumpDischargeMm*0.3?Math.sqrt(1/(1-Math.pow(ratio,4))):1;
    if(!finite(correction)||!(correction>0))return null;
    var usgpmPerLps=15.850323141489;
    var denominator=19.63*Math.pow(orificeSizeMm/25.4,2)*kFactor*correction;
    if(!(denominator>0))return null;
    var k=Math.pow(usgpmPerLps/denominator,2)*0.3048;
    return {k:k,orificeSizeMm:orificeSizeMm,pumpDischargeMm:pumpDischargeMm,kFactor:kFactor,correction:correction,method:'keyes-k-factor'};
  }
  function orificeHead(curve,flowLps){return curve&&finite(curve.k)?curve.k*flowLps*flowLps:null;}
  function afterOrificeHead(pumpHeadM,curve,flowLps){
    pumpHeadM=Number(pumpHeadM);var loss=orificeHead(curve,flowLps);
    return finite(pumpHeadM)&&finite(loss)?pumpHeadM-loss:null;
  }

  function findParallelIntersection(pump,diameter,speedRatio,pumpCount,headFn){
    pumpCount=Math.max(1,Math.min(6,Math.round(Number(pumpCount)||1)));
    if(typeof headFn!=='function')return null;
    var maxD=dmax(pump),fits=pumpFits(pump);
    var maxPer=(fits.head?fits.head.max:Math.max.apply(null,uniqueNumbers(pump.flow_lps)))*(diameter/maxD)*speedRatio;
    var maxTotal=maxPer*pumpCount;
    function diff(qTotal){
      var p=performance(pump,diameter,qTotal/pumpCount,speedRatio),hs=headFn(qTotal);
      return p&&finite(hs)?p.headM-hs:null;
    }
    var prevQ=0,prev=diff(0);if(!finite(prev))return null;
    if(Math.abs(prev)<1e-9){var p0=performance(pump,diameter,0,speedRatio);return {totalFlowLps:0,headM:p0.headM,perPumpFlowLps:0,pumpCount:pumpCount};}
    var steps=500;
    for(var i=1;i<=steps;i++){
      var q=maxTotal*i/steps,cur=diff(q);if(!finite(cur))continue;
      if(prev===0||cur===0||prev*cur<0){
        var lo=prevQ,hi=q,flo=prev;
        for(var j=0;j<70;j++){
          var mid=(lo+hi)/2,fm=diff(mid);if(!finite(fm)){hi=mid;continue;}
          if(flo*fm<=0)hi=mid;else{lo=mid;flo=fm;}
        }
        var qt=(lo+hi)/2,pp=performance(pump,diameter,qt/pumpCount,speedRatio);
        return pp?{totalFlowLps:qt,headM:pp.headM,perPumpFlowLps:qt/pumpCount,pumpCount:pumpCount,performance:pp}:null;
      }
      prevQ=q;prev=cur;
    }
    return null;
  }

  function fmt(v,d){
    return finite(v)?Number(v).toFixed(d===undefined?2:d):'—';
  }

  return {
    STANDARD_MOTORS:STANDARD_MOTORS,
    uniqueNumbers:uniqueNumbers,
    interpolate:interpolate,
    polyFit:polyFit,
    polyEval:polyEval,
    pumpFits:pumpFits,
    dmax:dmax,dmin:dmin,
    efficiencyAt:efficiencyAt,
    performance:performance,
    solveTheoreticalDiameter:solveTheoreticalDiameter,
    roundImpeller:roundImpeller,
    solveSpeedRatio:solveSpeedRatio,
    curvePoints:curvePoints,
    bepData:bepData,
    sizeMotor:sizeMotor,
    buildResult:buildResult,
    selectPumps:selectPumps,
    compareSelectionPriority:compareSelectionPriority,
    catalogModelCompare:catalogModelCompare,
    normalizeDutyPoints:normalizeDutyPoints,
    buildMultiResult:buildMultiResult,
    selectPumpsMulti:selectPumpsMulti,
    applyFlexibleSetting:applyFlexibleSetting,
    systemCurveStaticDuty:systemCurveStaticDuty,
    systemCurveTwoPoints:systemCurveTwoPoints,
    systemHead:systemHead,
    orificeCurveKnown:orificeCurveKnown,
    orificeCurvePhysical:orificeCurvePhysical,
    orificeCurveKFactor:orificeCurveKFactor,
    orificeHead:orificeHead,
    afterOrificeHead:afterOrificeHead,
    findParallelIntersection:findParallelIntersection,
    fmt:fmt,
    round:round
  };
});
