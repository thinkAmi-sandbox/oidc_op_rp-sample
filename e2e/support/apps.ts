import { readEnvFile } from "./env";

export const OP_URL = "http://localhost:3780";
export const RP_URL = "http://localhost:3781";
export const RS_URL = "http://localhost:3782";

/** RP / RS の E2E 用の環境変数。client_id / secret は OP の db/seeds.rb で作るダミー値 */
export const rpEnv = readEnvFile("rails_relying_party_of_backend/.env_e2e");
export const rsEnv = readEnvFile("rails_resource_server/.env_e2e");
