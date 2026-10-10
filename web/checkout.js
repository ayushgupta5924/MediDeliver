/* The fragment contains a short-lived checkout token, never a Supabase session. */
(async()=>{
  const status=document.getElementById('status'), button=document.getElementById('pay');
  let token=location.hash.slice(1);
  if(token) {sessionStorage.setItem('md-checkout',token);history.replaceState(null,'','/checkout.html');}
  else token=sessionStorage.getItem('md-checkout');
  async function call(action,body) {
    const response=await fetch(`/api/payments/${action}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(25000)});
    const result=await response.json();
    if(!response.ok) throw new Error(result.error || 'Payment could not be confirmed');
    return result;
  }
  try {
    const details=await call('checkout',{token});
    if(typeof window.Razorpay!=='function') throw new Error('Payment service could not load. Please reopen checkout.');
    button.textContent=`Pay ₹${(details.amount/100).toFixed(2)}`;
    status.textContent='Your pharmacy quote is ready. Payment is confirmed by the server after capture.';
    button.disabled=false;
    button.onclick=()=>{
      button.disabled=true;
      const gateway=new window.Razorpay({...details,description:'Pharmacy order',
        handler:async result=>{
          status.textContent='Verifying payment…';
          try {
            const verified=await call('verify',{token,...result});
            status.textContent=verified.status==='refund_pending'?'This order was cancelled or is no longer fulfillable. A full refund is queued.':'Payment confirmed. Return to MediDeliver to follow your order.';
            sessionStorage.removeItem('md-checkout');
          } catch {status.textContent='Payment confirmation is pending. Check your order before making another payment; we will reconcile it automatically.';}
        },modal:{ondismiss:()=>{button.disabled=false;status.textContent='Checkout closed. Check order status before retrying a payment.';}}});
      gateway.on('payment.failed',()=>{status.textContent='Payment was not confirmed. Check your order status before retrying.';button.disabled=false;});
      gateway.open();
    };
  } catch(error) {status.textContent=error.message || 'Checkout is unavailable. Return to your order and retry.';}
})();
