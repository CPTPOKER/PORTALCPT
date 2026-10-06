import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={ 'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS' };
const response=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers:cors});
 if(req.method!=='POST')return response(405,{error:'Método não permitido.'});
 try {
  const token=req.headers.get('Authorization')?.replace(/^Bearer\s+/i,'');
  if(!token)return response(401,{error:'Autenticação obrigatória.'});
  const url=Deno.env.get('SUPABASE_URL'),key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if(!url||!key)return response(503,{error:'Função não configurada.'});
  const service=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:{user},error:authError}=await service.auth.getUser(token);
  if(authError||!user)return response(401,{error:'Sessão inválida.'});
  const {data:profile,error:profileError}=await service.from('profiles').select('role,active').eq('id',user.id).single();
  if(profileError||profile?.role!=='admin'||!profile.active)return response(403,{error:'Acesso exclusivo do administrador.'});
  const input=await req.json();
  if(input.action==='create'){
   const name=typeof input.name==='string'?input.name.trim():'';
   const email=typeof input.email==='string'?input.email.trim().toLowerCase():'';
   const password=typeof input.password==='string'?input.password:'';
   if(!name||name.length>100||!/^\S+@\S+\.\S+$/.test(email)||password.length<8||password.length>128)return response(400,{error:'Informe nome, e-mail e senha de 8 a 128 caracteres.'});
   const {data,error}=await service.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{name}});
   if(error)return response(400,{error:'Não foi possível criar a conta. Verifique se o e-mail já existe e se a senha atende às regras do projeto.'});
   return response(201,{id:data.user.id});
  }
  if(input.action==='delete'){
   if(typeof input.user_id!=='string'||input.user_id===user.id)return response(400,{error:'Esta conta não pode ser excluída.'});
   const {data:target,error:targetError}=await service.from('profiles').select('id,role').eq('id',input.user_id).single();
   if(targetError||!target)return response(404,{error:'Usuário não encontrado.'});
   if(target.role==='admin')return response(403,{error:'Contas de administradores não podem ser excluídas.'});
   const {error:deleteError}=await service.auth.admin.deleteUser(input.user_id,false);
   if(deleteError)return response(500,{error:'Não foi possível excluir o usuário. Tente novamente.'});
   return response(200,{ok:true});
  }
  if(input.action==='set_active'){
   if(typeof input.user_id!=='string'||typeof input.active!=='boolean'||input.user_id===user.id)return response(400,{error:'Usuário inválido.'});
   const {data:target,error:targetError}=await service.from('profiles').select('id,role,active').eq('id',input.user_id).single();
   if(targetError||!target||target.role==='admin')return response(400,{error:'Somente contas de alunos podem ser alteradas.'});
   const {data:updated,error:updateError}=await service.from('profiles').update({active:input.active}).eq('id',input.user_id).select('id,active').single();
   if(updateError||!updated)return response(500,{error:'Não foi possível atualizar o acesso.'});
   return response(200,{ok:true,active:updated.active});
  }
  return response(400,{error:'Ação inválida.'});
 }catch{return response(500,{error:'Não foi possível processar a solicitação.'});}
});