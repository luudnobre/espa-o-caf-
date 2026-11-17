import {defineConfig, loadEnv} from 'vite';
export default defineConfig(({mode}) => {
  const env=loadEnv(mode,process.cwd(),'VITE_');
  const key=(env.VITE_SUPABASE_PUBLISHABLE_KEY||'').trim();
  if(key && key!=='SUA_CHAVE_PUBLICA' && !key.startsWith('sb_publishable_')) {
    let role; try {role=JSON.parse(Buffer.from(key.split('.')[1],'base64url').toString()).role;}catch{}
    if(role!=='anon') throw Error('Use somente a chave pública Publishable/anon do Supabase. Nunca use secret ou service_role.');
  }
  return {server:{allowedHosts:['terminal.local']}};
});
