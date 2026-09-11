/* tslint:disable */
/* eslint-disable */

/**
 * Connect session state — opaque JSON blob passed between WASM calls.
 *
 * Secret fields (encryption_root, my_dh_secret, signing_secret) are sensitive.
 * Store in secure storage (OS keychain), never log in plaintext.
 * Parse with: `JSON.parse(sessionStateJson) as TConnectSessionState`
 * Pass back as: `JSON.stringify(state)`
 */
export type TConnectSessionState = {
    encryption_root: string;   // hex, 32 bytes — DO NOT log
    my_dh_secret: string;      // hex, 32 bytes — DO NOT log
    peer_dh_public: string;    // hex, 32 bytes
    signing_public: string;    // hex, 32 bytes
    signing_secret: string;    // hex, 32 bytes — DO NOT log
    created_at: number;        // UNIX epoch seconds, set at handshake
    expires_at: number;        // UNIX epoch seconds (0 = no expiration, default = created_at + 24h)
};



export type TKeyPair = {
    public: string;
    secret: string;
};

export type TParamsOfDeployMultifactor = {
    wallet_name: string;
    zkid: string;
    password: string;
    proof: string;
    epk: string;
    esk: string;
    jwk_modulus: string;
    jwk_modulus_expire_at: number;
    index_mod_4: number;
    iss_base_64: string;
    header_base_64: string;
    epk_expire_at: number;
    kid: string;
    sub: string;
};

export type TParamsOfDeployMiner = {
    multifactor_address: string
    signer_keys: TKeyPair,
};

export type TParamsOfSetMiningKeys = {
    multifactor_address: string
    signer_keys: TKeyPair,
    mining_pubkey: string,
    app_id?: string,
    epk_expire_at?: number,
};

export type TParamsOfDelMiningKey = {
    multifactor_address: string;
    signer_keys: TKeyPair;
    app_id?: string;
    epk_expire_at?: number;
    and_wait?: boolean;
};

export type TParamsOfAddZKPFactor = {
    wallet_name: string;
    proof: string;
    epk: string;
    esk: string;
    header_base_64: string;
    epk_expire_at: number;
    jwk_expires_at: number;
    kid: string;
    sub: string;
    password: string
    zkid: string
}

export type TParamsOfChangeSeedPhrase = {
    password: string;
    signer_keys: TKeyPair;
    new_owner_keys: TKeyPair;
    multifactor_address: string;
}

export type TParamsOfGetMultifactorBalances = {
    multifactor_address: string;
};

export type TParamsOfGetTokensBalances = {
    multifactor_address: string;
    token_roots: { token_root: string; token_dapp: string }[];
};

export type TParamsOfGetHistory = {
    multifactor_address: string;
    token_id: string;
    page_size?: number;
    cursor?: string;
    mining_cursor?: string;
};

export type TParamsOfGetMinerAddress = {
    multifactor_address: string
};

export type TBuyShellsReq = {
    multifactor_address: string;
    usdc_amount: number;
    signer_keys: TKeyPair;
    bounce?: boolean;
};

export type TRedeemNacklReq = {
    multifactor_address: string;
    nackl_amount: number;
    signer_keys: TKeyPair;
    bounce?: boolean;
};

export type TMigrateTip3UsdcReq = {
    multifactor_address: string;
    token_root: string;
    token_dapp: string;
    amount_raw: string | number;
    signer_keys: TKeyPair;
    bounce?: boolean;
};

export type TClaimUsdcReq = {
    denom: number;
    order_id: number;
    signer_keys: TKeyPair;
};

export type TSendTokensDirectReq = {
    multifactor_address: string;
    destination_address: string;
    token_root: string;
    amount_raw: string | number;
    flags: number;
    signer_keys: TKeyPair;
    bounce?: boolean;
    /** Gas value in nanotons. Default: 1_000_000_000 (1 VMShell). */
    value?: number;
    /** ABI-encoded message body (base64). Carries a function call to the destination. */
    payload?: string;
};

export type TGetMySellOrdersReq = {
    multifactor_address: string;
    page_size?: number;
    cursor?: string;
};

export type TSellShellsReq = {
    multifactor_address: string;
    denom: number;
    signer_keys: TKeyPair;
    bounce?: boolean;
};

export type TSellShellsResult = {
    message_hash: string | null;
    order_id: number;
    denom: number;
    sell_order_address: string;
    sold: boolean;
    position_in_queue: number;
};

/**
 * Connect session state — opaque blob passed between WASM calls.
 *
 * Secret fields (encryption_root, my_dh_secret, signing_secret) are sensitive.
 * Store in secure storage (OS keychain), never log in plaintext.
 * Pass back to WASM as-is; do not modify fields.
 */
export type TConnectSessionState = {
    encryption_root: string;   // hex, 32 bytes — DO NOT log
    my_dh_secret: string;      // hex, 32 bytes — DO NOT log
    peer_dh_public: string;    // hex, 32 bytes
    signing_public: string;    // hex, 32 bytes
    signing_secret: string;    // hex, 32 bytes — DO NOT log
    created_at: number;        // UNIX epoch seconds, set at handshake
    expires_at: number;        // UNIX epoch seconds (0 = no expiration, default = created_at + 24h)
};

export type TParamsOfQueryConnectSessionMessages = {
    session_id: string;
    description: string;
    session_state?: TConnectSessionState;
    created_at_from?: number;
    before?: string;
    limit?: number;
};

/**
 * Saved data from `prepare_zk_login_v1` (carry through the OAuth round-trip).
 * Field names are camelCase because the underlying Rust struct uses camelCase.
 */
export type TZkLoginTempData = {
    maxEpoch: number;
    randomness: string;
    ephemeralPrivateKey: string;
};

export type TZkLoginCompleteWithProverParams = {
    savedData: TZkLoginTempData;
    jwt: string;
    jwtSub: string;
    jwtAud: string;
    userPassword: string;
    proverUrl: string;
};

export type TUpdateMultifactorZkIdReq = {
    address: string;
    zkid: string;
    password: string;
    proof: string;
    epk: string;
    esk: string;
    jwk_modulus: string;
    jwk_modulus_expire_at: number;
    index_mod_4: number;
    iss_base_64: string;
    header_base_64: string;
    epk_expire_at: number;
    pubkey: string;
    secretkey: string;
    kid: string;
    sub: string;
};

export type TDeleteZkpFactorByItselfReq = {
    multifactor_address: string;
    signer_keys: TKeyPair;
};

export type TParamsOfGetMultifactorInfo = {
    address: string;
};

export type TParamsOfGetMultifactorAddress = {
    pubkey: string;
};

export type TParamsGetMirrorAddress = {
    pubkey: string;
};

export type TGetEPKExpireReq = {
    epk: string;
    multifactor_address: string;
};

/**
 * Stage 5b — `prepare_multifactor_deploy_params` input.
 * Combines zk-login outputs with BIP39 owner keys + future multifactor address.
 */
export type TParamsOfPrepareDeploy = {
    zkid: string;
    password: string;
    proof: string;
    epk: string;
    esk: string;
    jwk_modulus: string;
    jwk_modulus_expire_at: number;
    index_mod_4: number;
    iss_base_64: string;
    header_base_64: string;
    epk_expire_at: number;
    keys: TKeyPair;
    kid: string;
    wallet_name: string;
    multifactor_address: string;
    sub: string;
};

export type TRootProviderCertificatesMap = Record<string, string>;

export type TTokenBalancesMap = Record<string, string>;
export type TNativeBalancesMap = Record<string, string>;
export type TMinerOwnerPublicMap = Record<string, string>;
export type TCandidateOwnerPubkeyExpirationMap = Record<string, string> | null;
export type TFactorsOrderedByTimestampMap = Record<string, string>;
export type TJwkData = {
    modulus: string;
    modulus_expire_at: string;
};
export type TJwkModulusDataMap = Record<string, TJwkData>;
export type TWhiteListOfAddressMap = Record<string, boolean>;




export type TKeyPair = {
    public: string;
    secret: string;
};

export type TParamsOfSign = {
    unsigned: string;
    keys: TKeyPair;
}



export type TParamsOfDeployMultisigViaGiver = {
    endpoints: string[];
    keys?: TKeyPair;
    owners_pubkey?: string[];
    req_confirms?: number;
    req_confirms_data?: number;
    constructor_value?: string;
    // v2.4 only. Omit to pass 0/0 and disable automatic SHELL-to-vmshell
    // conversion. Decimal strings preserve the full uint128 range.
    balance_config?: TMultisigBalanceConfig;
    giver_value?: string;
    // Map, NOT Record: serde on the Rust side deserializes a JS Map's numeric
    // keys into the u32 currency ids. A plain object/Record stringifies its keys
    // and the WASM rejects them ("invalid type: string, expected u32").
    giver_ecc?: Map<number, string>;
    wait_for_active?: boolean;
};

export type TMultisigBalanceConfig = {
    min_balance: string;
    target_balance: string;
};

export type TResultOfDeployMultisigViaGiver = {
    address: string;
    public: string;
    secret: string;
    already_deployed: boolean;
    deploy_tx?: string;
};

export type TParamsOfMultisigBalances = {
    endpoints: string[];
    address: string;
};



export type TParamsOfEnsureMiningKeysPropagated = {
    client_config: Record<string, unknown>;
    miner_address: string;
    app_id: string;
    expected_owner_public: string;
    max_attempts?: number;
    interval_ms?: number;
};

export type TParamsOfGetMinerAddressByWalletName = {
    client_config: Record<string, unknown>;
    wallet_name: string;
};



export class ActiveConnectSession {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly app_id: string | undefined;
    readonly deployed_at: bigint;
    readonly deployed_event_id: string;
    readonly description: string;
    readonly profile_address: string;
    readonly session_id: string | undefined;
}

export class BeeConnect {
    free(): void;
    [Symbol.dispose](): void;
    /**
     * Creates a `shared_key` session and returns payload + temporary owner
     * keys.
     */
    create_shared_key_session(app_id: string, ttl_secs?: number | null, nonce?: string | null): ResultOfCreateSharedKeySession;
    /**
     * Decodes and validates base64url connect payload (`payload` query
     * value).
     */
    decode_connect_payload_b64url(payload_b64url: string): ParsedConnectPayload;
    /**
     * Sends a `client_disconnect` message (`dir = c2w`) to the connected
     * profile. Performs DH re-key for forward secrecy.
     */
    disconnect_session(endpoints: string[], session_id: string, description: string, session_state_json: string, reason?: string | null, max_attempts?: number | null, interval_ms?: number | null): Promise<ResultOfDisconnectSession>;
    /**
     * Returns `true` if session profile is currently deployed.
     */
    is_session_profile_deployed(endpoints: string[], description: string): Promise<boolean>;
    /**
     * Creates a new wasm-facing `bee_connect` client wrapper.
     */
    constructor(max_rps?: number | null);
    /**
     * Small health-check helper for smoke tests.
     */
    ping(): string;
    /**
     * Queries one chunk of active connect sessions by multifactor.
     *
     * Returns at most 10 deployed `bee_connect` sessions and a cursor for the
     * next chunk. Optional `app_id` filters to one application.
     */
    query_active_sessions_by_multifactor(endpoints: string[], multifactor_address: string, app_id?: string | null, created_at_from?: bigint | null, before?: string | null): Promise<ResultOfQueryActiveSessionsByMultifactor>;
    /**
     * Sends `set_mining_keys` request (`dir = c2w`) to wallet over connect
     * profile. Performs DH re-key for forward secrecy.
     */
    request_set_mining_keys(endpoints: string[], session_id: string, description: string, session_state_json: string, app_id: string, owner_public: string, max_attempts?: number | null, interval_ms?: number | null): Promise<ResultOfRequestSetMiningKeys>;
    /**
     * Sends `sign_challenge` (`dir = c2w`) to the wallet. The wallet should
     * sign the nonce and respond with `challenge_response`.
     */
    request_sign_challenge(endpoints: string[], session_id: string, description: string, session_state_json: string, nonce: string, max_attempts?: number | null, interval_ms?: number | null): Promise<ResultOfRequestSignChallenge>;
    /**
     * Resolves deterministic `AuthProfile` address by `description`.
     */
    resolve_profile_address(endpoints: string[], description: string): Promise<string>;
    /**
     * Waits for `challenge_response` (`dir = w2c`) from the wallet.
     */
    wait_challenge_response(endpoints: string[], session_id: string, description: string, session_state_json?: string | null, created_at_from?: bigint | null, max_attempts?: number | null, interval_ms?: number | null): Promise<ResultOfWaitChallengeResponse>;
    /**
     * Waits for `set_mining_keys` request (`dir = c2w`) in session profile.
     */
    wait_set_mining_keys_request(endpoints: string[], session_id: string, description: string, created_at_from?: bigint | null, max_attempts?: number | null, interval_ms?: number | null, session_state_json?: string | null): Promise<ResultOfWaitSetMiningKeysRequest>;
    /**
     * Waits for the wallet's first `wallet_hello` message on the profile.
     */
    wait_wallet_hello(endpoints: string[], session_id: string, description: string, client_dh_secret: string, created_at_from?: bigint | null, max_attempts?: number | null, interval_ms?: number | null): Promise<ResultOfWaitWalletHello>;
}

export class ConnectSessionMessage {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    /**
     * `true` when the encrypted body was actually decrypted for this message.
     * `body_json` is not a substitute: it falls back to the raw envelope body
     * when decryption fails, so it is always non-empty.
     */
    readonly body_decrypted: boolean;
    readonly body_json: string;
    readonly challenge_epk_public: string | undefined;
    readonly challenge_nonce: string | undefined;
    readonly challenge_signature: string | undefined;
    readonly dir: string;
    readonly disconnect_reason: string | undefined;
    readonly event_created_at: bigint;
    readonly event_id: string;
    readonly mining_app_id: string | undefined;
    readonly mining_owner_public: string | undefined;
    readonly msg_type: string;
    readonly raw_message_json: string;
    readonly seq: bigint;
    /**
     * Session state snapshot taken immediately after `rekey_inbound` for this
     * message. Present only for c2w messages that triggered a successful DH
     * re-key. Use this when responding to the message (e.g. sending
     * `challenge_response` after receiving `sign_challenge`).
     */
    readonly session_state_after_json: string | undefined;
    readonly ts: bigint | undefined;
    readonly wallet_address: string | undefined;
    readonly wallet_name: string | undefined;
}

/**
 * High-level wasm API for crypto operations.
 */
export class Crypto {
    free(): void;
    [Symbol.dispose](): void;
    /**
     * Decrypts data previously encrypted with `encrypt`.
     */
    decrypt(encrypted: string, password: string): Promise<string>;
    /**
     * Encrypts plaintext with a password.
     */
    encrypt(plaintext: string, password: string): Promise<CryptoResultOfEncrypt>;
    /**
     * Generates a short-lived mining keypair.
     */
    gen_mining_keys(): Promise<CryptoResultOfGetKeys>;
    /**
     * Generates a mnemonic with the requested word count and derives keys from
     * it.
     */
    gen_mnemonic_and_derive_keys(word_count: number): Promise<CryptoResultOfGenSeedAndKeys>;
    /**
     * Derives keys using the requested mnemonic word count.
     */
    get_keys_from_mnemonic(phrase: string, word_count: number): Promise<CryptoResultOfGetKeys>;
    /**
     * Derives keys from a mnemonic phrase using a specific HD derivation path.
     */
    get_keys_from_mnemonic_with_path(phrase: string, path: string, word_count: number): Promise<CryptoResultOfGetKeys>;
    /**
     * Computes a salted password hash in `v3:<salt_hex>:<dk_hex>` format.
     */
    hash_password(data: string): Promise<string>;
    /**
     * Creates a crypto client bound to network endpoints.
     */
    constructor(endpoints: string[]);
    /**
     * Signs base64-encoded payload with an Ed25519 keypair.
     */
    sign(params_js: TParamsOfSign): Promise<CryptoResultOfSign>;
    /**
     * Verifies mnemonic checksum, format, and the requested word count.
     */
    verify_mnemonic(phrase: string, word_count: number): Promise<boolean>;
    /**
     * Verifies a plain password against a `v2` or `v3` hash.
     */
    verify_password_hash(password: string, expected: string): Promise<boolean>;
}

export class CryptoResultOfEncrypt {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly encrypted: string;
}

export class CryptoResultOfGenSeedAndKeys {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly keys: CryptoResultOfGetKeys;
    readonly phrase: string;
}

export class CryptoResultOfGetKeys {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly public: string;
    readonly secret: string;
}

export class CryptoResultOfSign {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly signature: string;
    readonly signed: string;
}

export class GraphqlBlockData {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    seq_no: bigint;
}

export class IssBase64Details {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly index_mod4: number;
    readonly value: string;
}

export class Miner {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    add_tap(x: number, y: number): void;
    can_start(): boolean;
    get_current_block(): Promise<GraphqlBlockData>;
    get_miner_data(): Promise<MinerAccountData>;
    get_reward(): Promise<void>;
    static new(endpoints: string[], app_id: string, address: string, public_key: string, secret_key: string): Promise<Miner>;
    remove_seed(seed: string): void;
    start(duration_ms: number, callback: Function): void;
    stop(): void;
}

export class MinerAccountData {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    epoch_5m_start_old: bigint;
    epoch_5m_start: bigint;
    epoch_start: bigint;
    /**
     * `_miningDurSum` — total mining duration accrued this 24-hour epoch.
     */
    mining_dur_sum: bigint;
    /**
     * `_modifiedTapSum` — reputation-weighted tap total (drives the payout).
     */
    modified_tap_sum: bigint;
    /**
     * `_oldTapsSize` — session count from the previous ~5-minute epoch.
     */
    old_taps_size: bigint;
    tap_sum_5m: bigint;
    tap_sum: bigint;
    /**
     * `_tapsSize` — mining sessions recorded in the current ~5-minute reward
     * epoch. Resets when `epoch_5m_start` rolls.
     */
    taps_size: bigint;
}

/**
 * Decoded `Multifactor` contract account state. Mirrors
 * `ackinacki_kit::contracts::mvsystem::multifactor::AccountData`.
 */
export class MultifactorAccountData {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly candidate_new_owner_pubkey_and_expiration: TCandidateOwnerPubkeyExpirationMap;
    readonly factors_len: string;
    readonly factors_ordered_by_timestamp: TFactorsOrderedByTimestampMap;
    readonly force_remove_oldest: boolean;
    readonly index_mod_4: string;
    readonly iss_base_64: string;
    readonly jwk_modulus_data: TJwkModulusDataMap;
    readonly jwk_modulus_data_len: string;
    readonly jwk_update_key: string;
    readonly m_security_cards_len: string;
    readonly m_transactions_len: string;
    readonly max_cleanup_txns: string;
    readonly min_value: string;
    readonly name: string;
    readonly owner_pubkey: string;
    readonly pub_recovery_key: string;
    readonly root: string;
    readonly use_security_card: boolean;
    readonly wasm_hash: string;
    readonly white_list_of_address: TWhiteListOfAddressMap;
    readonly zkid: string;
}

export class ParsedConnectPayload {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly app_id: string;
    readonly description: string;
    readonly expires_at: bigint;
    readonly nonce: string | undefined;
    readonly session_id: string;
    readonly v: string;
}

/**
 * Signed deploy params produced by `prepare_multifactor_deploy_params`.
 * Mirrors `ackinacki_kit::contracts::mvsystem::mirror::ParamsOfDeployMultifactor`.
 */
export class PreparedDeployParams {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly epk: string;
    readonly epk_expire_at: bigint;
    readonly epk_sig: string;
    readonly header_base_64: string;
    readonly index_mod_4: number;
    readonly iss_base_64: string;
    readonly jwk_modulus: string;
    readonly jwk_modulus_expire_at: bigint;
    readonly jwk_update_key: string;
    readonly jwk_update_key_sig: string;
    readonly kid: string;
    readonly name: string;
    readonly proof: string;
    readonly provider: string;
    readonly pub_recovery_key: string;
    readonly pub_recovery_key_sig: string;
    readonly root_provider_certificates: TRootProviderCertificatesMap;
    readonly zkid: string;
}

export class ResultGetMirrorAddress {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly address: string;
}

export class ResultOfAddZKPFactor {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly address: string;
    readonly message_id: string | undefined;
    readonly message_ids: string[];
    readonly name: string;
    readonly password_hash: string;
    readonly pubkey: string;
    readonly signing_keys: ResultOfGetKeys;
}

export class ResultOfBlockchainWrite {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly message_ids: string[];
    readonly pending_reason: string | undefined;
    readonly pending_stage: string | undefined;
}

export class ResultOfCheckNameAvailability {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly is_available: boolean;
    readonly multifactor_address: string | undefined;
}

export class ResultOfCreateSharedKeySession {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly app_id: string;
    readonly client_dh_public: string;
    readonly client_dh_secret: string;
    readonly created_at: bigint;
    readonly deep_link: string;
    readonly description: string;
    readonly expires_at: bigint;
    readonly payload_b64url: string;
    readonly payload_json: string;
    readonly session_id: string;
}

export class ResultOfDeployMultifactor {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly address: string;
    readonly message_id: string | undefined;
    readonly message_ids: string[];
    readonly name: string;
    readonly password_hash: string;
    readonly pending_reason: string | undefined;
    readonly pending_stage: string | undefined;
    readonly phrase: string;
    readonly pubkey: string;
    readonly signing_keys: ResultOfGetKeys;
}

export class ResultOfDisconnectSession {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly message_id: string | undefined;
    readonly profile_address: string;
    readonly raw_message_json: string;
    readonly updated_session_state_json: string;
}

export class ResultOfGenMiningKeys {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly deep_link: string;
    readonly public: string;
    readonly secret: string;
}

export class ResultOfGetEPKExpireAt {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly epk_expire_at: bigint;
}

export class ResultOfGetHistory {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly data: TxData[];
    readonly has_next_page: boolean;
    readonly next_cursor: string | undefined;
    readonly next_mining_cursor: string | undefined;
}

export class ResultOfGetKeys {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly public: string;
    readonly secret: string;
}

export class ResultOfGetMinerDetails {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly address: string;
    readonly owner_address: string;
    readonly owner_public: TMinerOwnerPublicMap;
}

export class ResultOfGetMultifactorDetails {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly address: string;
    readonly candidate_new_owner_pubkey_and_expiration: TCandidateOwnerPubkeyExpirationMap;
    readonly factors_len: string;
    readonly factors_ordered_by_timestamp: TFactorsOrderedByTimestampMap;
    readonly force_remove_oldest: boolean;
    readonly index_mod_4: string;
    readonly iss_base_64: string;
    readonly jwk_modulus_data: TJwkModulusDataMap;
    readonly jwk_modulus_data_len: string;
    readonly jwk_update_key: string;
    readonly m_security_cards_len: string;
    readonly m_transactions_len: string;
    readonly max_cleanup_txns: string;
    readonly min_value: string;
    readonly name: string;
    readonly owner_pubkey: string;
    readonly pub_recovery_key: string;
    readonly root: string;
    readonly use_security_card: boolean;
    readonly wasm_hash: string;
    readonly white_list_of_address: TWhiteListOfAddressMap;
    readonly zkid: string;
}

export class ResultOfGetMultifactorInfo {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly data: MultifactorAccountData | undefined;
}

export class ResultOfGetMvMultifactorAddress {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly address: string;
}

export class ResultOfGetNativeBalances {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly ecc: TNativeBalancesMap;
    readonly popitgame: TNativeBalancesMap;
}

export class ResultOfGetTokensBalances {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly tokens: TTokenBalancesMap;
}

export class ResultOfQueryActiveSessionsByMultifactor {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly exhausted_active: boolean;
    readonly next_before: string | undefined;
    readonly sessions: Array<any>;
}

export class ResultOfQuerySessionMessages {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly messages: Array<any>;
    readonly next_before: string | undefined;
    readonly profile_address: string;
    readonly updated_session_state_json: string | undefined;
}

export class ResultOfRequestSetMiningKeys {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly app_id: string;
    readonly message_id: string | undefined;
    readonly owner_public: string;
    readonly profile_address: string;
    readonly raw_message_json: string;
    readonly updated_session_state_json: string;
}

export class ResultOfRequestSignChallenge {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly message_id: string | undefined;
    readonly nonce: string;
    readonly profile_address: string;
    readonly raw_message_json: string;
    readonly sent_at: bigint;
    readonly updated_session_state_json: string;
}

/**
 * Wraps `ackinacki_kit::tvm_client::processing::ResultOfSendMessage`.
 * Numeric `exit_code` is signed (i32) and survives the boundary as-is.
 */
export class ResultOfSendMessage {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly aborted: boolean | undefined;
    readonly block_hash: string | undefined;
    readonly current_time: string | undefined;
    readonly exit_code: number | undefined;
    readonly message_hash: string | undefined;
    readonly producers: string[];
    readonly thread_id: string | undefined;
    readonly tx_hash: string | undefined;
}

export class ResultOfValidateWalletName {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly error_code: WalletNameErrorCode | undefined;
    readonly is_valid: boolean;
}

export class ResultOfWaitChallengeResponse {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly epk_public: string | undefined;
    readonly event_created_at: bigint;
    readonly event_id: string;
    readonly nonce: string;
    readonly profile_address: string;
    readonly raw_message_json: string;
    readonly signature: string;
    readonly updated_session_state_json: string | undefined;
    readonly wallet_address: string;
}

export class ResultOfWaitSetMiningKeysRequest {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly app_id: string;
    readonly event_created_at: bigint;
    readonly event_id: string;
    readonly owner_public: string;
    readonly profile_address: string;
    readonly raw_message_json: string;
    readonly updated_session_state_json: string | undefined;
}

export class ResultOfWaitWalletHello {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly epk_public: string | undefined;
    readonly event_created_at: bigint;
    readonly event_id: string;
    readonly nonce: string | undefined;
    readonly profile_address: string;
    readonly raw_message_json: string;
    readonly session_state_json: string;
    readonly signature: string | undefined;
    readonly wallet_address: string;
    readonly wallet_name: string;
}

export class TxData {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly created_at: string;
    readonly id: string;
    readonly src_name: string | undefined;
    readonly tx_type: string;
    readonly value: string;
}

export class Wallet {
    free(): void;
    [Symbol.dispose](): void;
    add_zkp_factor(params_js: TParamsOfAddZKPFactor): Promise<ResultOfAddZKPFactor>;
    /**
     * Like [`add_zkp_factor`], but invokes `on_progress(event)` for each
     * `add_factor` milestone (`jwk?` → `submitted` → `confirming`… →
     * `confirmed`), where `event` is a plain object `{ op, stage, detail?,
     * pct? }`. On confirmation timeout the call rejects with a terminal error.
     */
    add_zkp_factor_with_progress(params_js: TParamsOfAddZKPFactor, on_progress: Function): Promise<ResultOfAddZKPFactor>;
    buy_shells(params_js: TBuyShellsReq): Promise<ResultOfBlockchainWrite>;
    change_seed_phrase(params_js: TParamsOfChangeSeedPhrase): Promise<ResultOfBlockchainWrite>;
    check_name_availability(wallet_name: string): Promise<ResultOfCheckNameAvailability>;
    claim_usdc(params_js: TClaimUsdcReq): Promise<any>;
    /**
     * Completes zk-login by preparing local payload, fetching prover proofs
     * and finalizing proof compression.
     */
    complete_zk_login_with_prover_v1(params_js: TZkLoginCompleteWithProverParams): Promise<ZkLoginCompleteWithProverResult>;
    /**
     * Like [`complete_zk_login_with_prover_v1`], but invokes
     * `on_progress(event)` for each `prove` milestone (`started` →
     * `finished`), where `event` is `{ op, stage, detail?, pct? }`.
     */
    complete_zk_login_with_prover_v1_with_progress(params_js: TZkLoginCompleteWithProverParams, on_progress: Function): Promise<ZkLoginCompleteWithProverResult>;
    decode_connect_payload_b64url(payload_b64: string): any;
    del_mining_key(params_js: TParamsOfDelMiningKey): Promise<ResultOfBlockchainWrite>;
    /**
     * Deletes currently used ZKP factor by its own signer key.
     */
    delete_zkp_factor_by_itself(params_js: TDeleteZkpFactorByItselfReq): Promise<ResultOfSendMessage>;
    /**
     * Deploy miner as a separate use case.
     * Skips deploy if miner is already deployed.
     */
    deploy_miner(params_js: TParamsOfDeployMiner): Promise<ResultOfBlockchainWrite>;
    /**
     * Like [`deploy_miner`], but invokes `on_progress(event)` for each
     * `deploy_miner` milestone (`resolving` → `deploying` → `confirmed`/
     * `pending`/`failed`), where `event` is `{ op, stage, detail?, pct? }`.
     */
    deploy_miner_with_progress(params_js: TParamsOfDeployMiner, on_progress: Function): Promise<ResultOfBlockchainWrite>;
    /**
     * Deploy multifactor wallet only (does not deploy miner).
     */
    deploy_wallet(params_js: TParamsOfDeployMultifactor): Promise<ResultOfDeployMultifactor>;
    /**
     * Like [`deploy_wallet`], but invokes `on_progress(event)` for each
     * `deploy` milestone (`preparing` → `deploying` → `submitted` →
     * `activating` → `active` → `configuring` → `confirmed`/`pending`/
     * `failed`), where `event` is `{ op, stage, detail?, pct? }`.
     */
    deploy_wallet_with_progress(params_js: TParamsOfDeployMultifactor, on_progress: Function): Promise<ResultOfDeployMultifactor>;
    /**
     * Returns expiration timestamp for a factor identified by EPK.
     */
    get_epk_expire_at(params_js: TGetEPKExpireReq): Promise<ResultOfGetEPKExpireAt>;
    get_history(params_js: TParamsOfGetHistory): Promise<ResultOfGetHistory>;
    get_miner_address(params_js: TParamsOfGetMinerAddress): Promise<string>;
    get_miner_details_by_multifactor_address(multifactor_address: string): Promise<ResultOfGetMinerDetails>;
    /**
     * Resolves mirror address for an owner pubkey.
     */
    get_mirror_address(params_js: TParamsGetMirrorAddress): ResultGetMirrorAddress;
    /**
     * Resolves multifactor address by owner pubkey.
     */
    get_multifactor_address(params_js: TParamsOfGetMultifactorAddress): Promise<ResultOfGetMvMultifactorAddress>;
    get_multifactor_balances(params_js: TParamsOfGetMultifactorBalances): Promise<ResultOfGetNativeBalances>;
    get_multifactor_data_by_name(wallet_name: string): Promise<ResultOfGetMultifactorDetails | undefined>;
    /**
     * Returns decoded multifactor contract state by address. `data` is `null`
     * when the contract is not deployed or has no decodable account data.
     */
    get_multifactor_info(params_js: TParamsOfGetMultifactorInfo): Promise<ResultOfGetMultifactorInfo>;
    get_my_sell_orders(params_js: TGetMySellOrdersReq): Promise<any>;
    get_nackl_redeem_rate(): Promise<any>;
    get_tokens_balances(params_js: TParamsOfGetTokensBalances): Promise<ResultOfGetTokensBalances>;
    migrate_tip3_usdc(params_js: TMigrateTip3UsdcReq): Promise<ResultOfBlockchainWrite>;
    constructor(endpoints: string[], archive_endpoints: string[] | null | undefined, api_url: string, app_id: string, api_token?: string | null, max_rps?: number | null);
    /**
     * Stage 5b — builds signed `ParamsOfDeployMultifactor` (epk_sig,
     * recovery key + sig, jwk-update key + sig, provider certificates).
     * Does not send anything on-chain.
     */
    prepare_multifactor_deploy_params(params_js: TParamsOfPrepareDeploy): Promise<PreparedDeployParams>;
    /**
     * Stage 1 of zk-login: generates ephemeral ed25519 keypair and the
     * Poseidon-based `nonce` to bind to the OAuth `nonce=` parameter.
     * Uses `Date.now()` (via js_sys) as the time source.
     */
    prepare_zk_login_v1(): ZkLoginPrepareResult;
    query_connect_session_messages(params_js: TParamsOfQueryConnectSessionMessages): Promise<ResultOfQuerySessionMessages>;
    redeem_nackl(params_js: TRedeemNacklReq): Promise<ResultOfBlockchainWrite>;
    sell_shells(params_js: TSellShellsReq): Promise<any>;
    send_tokens_direct(params_js: TSendTokensDirectReq): Promise<ResultOfBlockchainWrite>;
    /**
     * set mining keys for the app_id specified in sdk init
     */
    set_mining_keys(params_js: TParamsOfSetMiningKeys): Promise<ResultOfBlockchainWrite>;
    /**
     * Replaces wallet ZK identity payload (`zkid`, proof, factor, JWK data).
     */
    update_zk_id(params_js: TUpdateMultifactorZkIdReq): Promise<ResultOfSendMessage>;
    validate_name(wallet_name: string): ResultOfValidateWalletName;
}

export enum WalletNameErrorCode {
    InvalidCharacters = 1,
    ConsecutiveHyphens = 2,
    ConsecutiveUnderscores = 3,
    StartsWithSymbol = 4,
    TooLong = 5,
    TooShort = 6,
}

export class ZkLoginCompleteWithProverResult {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly ephemeral_private_key: string;
    readonly ephemeral_public_key_in_hex: string;
    readonly ephemeral_secret_key_in_hex: string;
    readonly header_base64: string;
    readonly iss_base64_details: IssBase64Details;
    readonly max_epoch: bigint;
    readonly zk_proof_compressed: string;
    readonly zkid: string;
}

export class ZkLoginPrepareResult {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    readonly ephemeral_private_key: string;
    readonly max_epoch: bigint;
    readonly nonce: string;
    readonly randomness: string;
}

/**
 * Free function (no `Wallet` instance, no api_url/app_id): deploy a flat
 * Multisig on shellnet, funding the future address from the default giver.
 * Always returns the owner keypair — the frontend MUST persist `secret`.
 */
export function deploy_multisig_via_giver(params: TParamsOfDeployMultisigViaGiver): Promise<TResultOfDeployMultisigViaGiver>;

export function ensure_mining_keys_propagated(params: TParamsOfEnsureMiningKeysPropagated): Promise<void>;

export function gen_mining_keys(app_id: string): Promise<ResultOfGenMiningKeys>;

export function get_miner_address_by_wallet_name(params: TParamsOfGetMinerAddressByWalletName): Promise<string>;

/**
 * Free function: ECC balances of any account by address as
 * `{ currency_id: raw_amount_string }`. Generic — works on the canonical
 * Multisig, unlike the multifactor-specific balance reader.
 */
export function multisig_balances(params: TParamsOfMultisigBalances): Promise<Record<number, string>>;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly __wbg_activeconnectsession_free: (a: number, b: number) => void;
    readonly __wbg_beeconnect_free: (a: number, b: number) => void;
    readonly __wbg_connectsessionmessage_free: (a: number, b: number) => void;
    readonly __wbg_crypto_free: (a: number, b: number) => void;
    readonly __wbg_cryptoresultofencrypt_free: (a: number, b: number) => void;
    readonly __wbg_cryptoresultofgenseedandkeys_free: (a: number, b: number) => void;
    readonly __wbg_cryptoresultofgetkeys_free: (a: number, b: number) => void;
    readonly __wbg_cryptoresultofsign_free: (a: number, b: number) => void;
    readonly __wbg_get_graphqlblockdata_seq_no: (a: number) => bigint;
    readonly __wbg_get_mineraccountdata_epoch_5m_start: (a: number) => bigint;
    readonly __wbg_get_mineraccountdata_epoch_5m_start_old: (a: number) => bigint;
    readonly __wbg_get_mineraccountdata_epoch_start: (a: number) => bigint;
    readonly __wbg_get_mineraccountdata_mining_dur_sum: (a: number) => [bigint, bigint];
    readonly __wbg_get_mineraccountdata_modified_tap_sum: (a: number) => [bigint, bigint];
    readonly __wbg_get_mineraccountdata_old_taps_size: (a: number) => [bigint, bigint];
    readonly __wbg_get_mineraccountdata_tap_sum: (a: number) => [bigint, bigint];
    readonly __wbg_get_mineraccountdata_tap_sum_5m: (a: number) => [bigint, bigint];
    readonly __wbg_get_mineraccountdata_taps_size: (a: number) => [bigint, bigint];
    readonly __wbg_graphqlblockdata_free: (a: number, b: number) => void;
    readonly __wbg_issbase64details_free: (a: number, b: number) => void;
    readonly __wbg_miner_free: (a: number, b: number) => void;
    readonly __wbg_mineraccountdata_free: (a: number, b: number) => void;
    readonly __wbg_multifactoraccountdata_free: (a: number, b: number) => void;
    readonly __wbg_parsedconnectpayload_free: (a: number, b: number) => void;
    readonly __wbg_prepareddeployparams_free: (a: number, b: number) => void;
    readonly __wbg_resultgetmirroraddress_free: (a: number, b: number) => void;
    readonly __wbg_resultofaddzkpfactor_free: (a: number, b: number) => void;
    readonly __wbg_resultofblockchainwrite_free: (a: number, b: number) => void;
    readonly __wbg_resultofchecknameavailability_free: (a: number, b: number) => void;
    readonly __wbg_resultofcreatesharedkeysession_free: (a: number, b: number) => void;
    readonly __wbg_resultofdeploymultifactor_free: (a: number, b: number) => void;
    readonly __wbg_resultofdisconnectsession_free: (a: number, b: number) => void;
    readonly __wbg_resultofgenminingkeys_free: (a: number, b: number) => void;
    readonly __wbg_resultofgetepkexpireat_free: (a: number, b: number) => void;
    readonly __wbg_resultofgethistory_free: (a: number, b: number) => void;
    readonly __wbg_resultofgetkeys_free: (a: number, b: number) => void;
    readonly __wbg_resultofgetminerdetails_free: (a: number, b: number) => void;
    readonly __wbg_resultofgetmultifactordetails_free: (a: number, b: number) => void;
    readonly __wbg_resultofgetmultifactorinfo_free: (a: number, b: number) => void;
    readonly __wbg_resultofgetmvmultifactoraddress_free: (a: number, b: number) => void;
    readonly __wbg_resultofgetnativebalances_free: (a: number, b: number) => void;
    readonly __wbg_resultofgettokensbalances_free: (a: number, b: number) => void;
    readonly __wbg_resultofqueryactivesessionsbymultifactor_free: (a: number, b: number) => void;
    readonly __wbg_resultofquerysessionmessages_free: (a: number, b: number) => void;
    readonly __wbg_resultofrequestsetminingkeys_free: (a: number, b: number) => void;
    readonly __wbg_resultofrequestsignchallenge_free: (a: number, b: number) => void;
    readonly __wbg_resultofsendmessage_free: (a: number, b: number) => void;
    readonly __wbg_resultofvalidatewalletname_free: (a: number, b: number) => void;
    readonly __wbg_resultofwaitchallengeresponse_free: (a: number, b: number) => void;
    readonly __wbg_resultofwaitsetminingkeysrequest_free: (a: number, b: number) => void;
    readonly __wbg_resultofwaitwallethello_free: (a: number, b: number) => void;
    readonly __wbg_set_graphqlblockdata_seq_no: (a: number, b: bigint) => void;
    readonly __wbg_set_mineraccountdata_epoch_5m_start: (a: number, b: bigint) => void;
    readonly __wbg_set_mineraccountdata_epoch_5m_start_old: (a: number, b: bigint) => void;
    readonly __wbg_set_mineraccountdata_epoch_start: (a: number, b: bigint) => void;
    readonly __wbg_set_mineraccountdata_mining_dur_sum: (a: number, b: bigint, c: bigint) => void;
    readonly __wbg_set_mineraccountdata_modified_tap_sum: (a: number, b: bigint, c: bigint) => void;
    readonly __wbg_set_mineraccountdata_old_taps_size: (a: number, b: bigint, c: bigint) => void;
    readonly __wbg_set_mineraccountdata_tap_sum: (a: number, b: bigint, c: bigint) => void;
    readonly __wbg_set_mineraccountdata_tap_sum_5m: (a: number, b: bigint, c: bigint) => void;
    readonly __wbg_set_mineraccountdata_taps_size: (a: number, b: bigint, c: bigint) => void;
    readonly __wbg_txdata_free: (a: number, b: number) => void;
    readonly __wbg_wallet_free: (a: number, b: number) => void;
    readonly __wbg_zklogincompletewithproverresult_free: (a: number, b: number) => void;
    readonly __wbg_zkloginprepareresult_free: (a: number, b: number) => void;
    readonly activeconnectsession_app_id: (a: number) => [number, number];
    readonly activeconnectsession_deployed_at: (a: number) => bigint;
    readonly activeconnectsession_deployed_event_id: (a: number) => [number, number];
    readonly activeconnectsession_description: (a: number) => [number, number];
    readonly activeconnectsession_profile_address: (a: number) => [number, number];
    readonly activeconnectsession_session_id: (a: number) => [number, number];
    readonly beeconnect_create_shared_key_session: (a: number, b: number, c: number, d: number, e: number, f: number) => [number, number, number];
    readonly beeconnect_decode_connect_payload_b64url: (a: number, b: number, c: number) => [number, number, number];
    readonly beeconnect_disconnect_session: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: number, l: number, m: number) => any;
    readonly beeconnect_is_session_profile_deployed: (a: number, b: number, c: number, d: number, e: number) => any;
    readonly beeconnect_new: (a: number) => number;
    readonly beeconnect_ping: (a: number) => [number, number];
    readonly beeconnect_query_active_sessions_by_multifactor: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: bigint, j: number, k: number) => any;
    readonly beeconnect_request_set_mining_keys: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: number, l: number, m: number, n: number, o: number) => any;
    readonly beeconnect_request_sign_challenge: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: number, l: number, m: number) => any;
    readonly beeconnect_resolve_profile_address: (a: number, b: number, c: number, d: number, e: number) => any;
    readonly beeconnect_wait_challenge_response: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: bigint, l: number, m: number) => any;
    readonly beeconnect_wait_set_mining_keys_request: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: bigint, j: number, k: number, l: number, m: number) => any;
    readonly beeconnect_wait_wallet_hello: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: bigint, l: number, m: number) => any;
    readonly connectsessionmessage_body_decrypted: (a: number) => number;
    readonly connectsessionmessage_body_json: (a: number) => [number, number];
    readonly connectsessionmessage_challenge_epk_public: (a: number) => [number, number];
    readonly connectsessionmessage_challenge_nonce: (a: number) => [number, number];
    readonly connectsessionmessage_challenge_signature: (a: number) => [number, number];
    readonly connectsessionmessage_dir: (a: number) => [number, number];
    readonly connectsessionmessage_disconnect_reason: (a: number) => [number, number];
    readonly connectsessionmessage_event_created_at: (a: number) => bigint;
    readonly connectsessionmessage_event_id: (a: number) => [number, number];
    readonly connectsessionmessage_mining_app_id: (a: number) => [number, number];
    readonly connectsessionmessage_mining_owner_public: (a: number) => [number, number];
    readonly connectsessionmessage_msg_type: (a: number) => [number, number];
    readonly connectsessionmessage_raw_message_json: (a: number) => [number, number];
    readonly connectsessionmessage_seq: (a: number) => bigint;
    readonly connectsessionmessage_session_state_after_json: (a: number) => [number, number];
    readonly connectsessionmessage_ts: (a: number) => [number, bigint];
    readonly connectsessionmessage_wallet_address: (a: number) => [number, number];
    readonly connectsessionmessage_wallet_name: (a: number) => [number, number];
    readonly crypto_decrypt: (a: number, b: number, c: number, d: number, e: number) => any;
    readonly crypto_encrypt: (a: number, b: number, c: number, d: number, e: number) => any;
    readonly crypto_gen_mining_keys: (a: number) => any;
    readonly crypto_gen_mnemonic_and_derive_keys: (a: number, b: number) => any;
    readonly crypto_get_keys_from_mnemonic: (a: number, b: number, c: number, d: number) => any;
    readonly crypto_get_keys_from_mnemonic_with_path: (a: number, b: number, c: number, d: number, e: number, f: number) => any;
    readonly crypto_hash_password: (a: number, b: number, c: number) => any;
    readonly crypto_new: (a: number, b: number) => [number, number, number];
    readonly crypto_sign: (a: number, b: any) => any;
    readonly crypto_verify_mnemonic: (a: number, b: number, c: number, d: number) => any;
    readonly crypto_verify_password_hash: (a: number, b: number, c: number, d: number, e: number) => any;
    readonly cryptoresultofencrypt_encrypted: (a: number) => [number, number];
    readonly cryptoresultofgenseedandkeys_keys: (a: number) => number;
    readonly cryptoresultofgenseedandkeys_phrase: (a: number) => [number, number];
    readonly cryptoresultofgetkeys_public: (a: number) => [number, number];
    readonly cryptoresultofgetkeys_secret: (a: number) => [number, number];
    readonly cryptoresultofsign_signature: (a: number) => [number, number];
    readonly cryptoresultofsign_signed: (a: number) => [number, number];
    readonly deploy_multisig_via_giver: (a: any) => any;
    readonly ensure_mining_keys_propagated: (a: any) => any;
    readonly gen_mining_keys: (a: number, b: number) => any;
    readonly get_miner_address_by_wallet_name: (a: any) => any;
    readonly issbase64details_index_mod4: (a: number) => number;
    readonly issbase64details_value: (a: number) => [number, number];
    readonly miner_add_tap: (a: number, b: number, c: number) => [number, number];
    readonly miner_can_start: (a: number) => number;
    readonly miner_get_current_block: (a: number) => any;
    readonly miner_get_miner_data: (a: number) => any;
    readonly miner_get_reward: (a: number) => any;
    readonly miner_new: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number) => any;
    readonly miner_remove_seed: (a: number, b: number, c: number) => void;
    readonly miner_start: (a: number, b: number, c: any) => [number, number];
    readonly miner_stop: (a: number) => void;
    readonly multifactoraccountdata_candidate_new_owner_pubkey_and_expiration: (a: number) => any;
    readonly multifactoraccountdata_factors_len: (a: number) => [number, number];
    readonly multifactoraccountdata_factors_ordered_by_timestamp: (a: number) => any;
    readonly multifactoraccountdata_force_remove_oldest: (a: number) => number;
    readonly multifactoraccountdata_index_mod_4: (a: number) => [number, number];
    readonly multifactoraccountdata_iss_base_64: (a: number) => [number, number];
    readonly multifactoraccountdata_jwk_modulus_data: (a: number) => any;
    readonly multifactoraccountdata_jwk_modulus_data_len: (a: number) => [number, number];
    readonly multifactoraccountdata_jwk_update_key: (a: number) => [number, number];
    readonly multifactoraccountdata_m_security_cards_len: (a: number) => [number, number];
    readonly multifactoraccountdata_m_transactions_len: (a: number) => [number, number];
    readonly multifactoraccountdata_max_cleanup_txns: (a: number) => [number, number];
    readonly multifactoraccountdata_min_value: (a: number) => [number, number];
    readonly multifactoraccountdata_name: (a: number) => [number, number];
    readonly multifactoraccountdata_owner_pubkey: (a: number) => [number, number];
    readonly multifactoraccountdata_pub_recovery_key: (a: number) => [number, number];
    readonly multifactoraccountdata_root: (a: number) => [number, number];
    readonly multifactoraccountdata_use_security_card: (a: number) => number;
    readonly multifactoraccountdata_wasm_hash: (a: number) => [number, number];
    readonly multifactoraccountdata_white_list_of_address: (a: number) => any;
    readonly multifactoraccountdata_zkid: (a: number) => [number, number];
    readonly multisig_balances: (a: any) => any;
    readonly parsedconnectpayload_app_id: (a: number) => [number, number];
    readonly parsedconnectpayload_description: (a: number) => [number, number];
    readonly parsedconnectpayload_expires_at: (a: number) => bigint;
    readonly parsedconnectpayload_nonce: (a: number) => [number, number];
    readonly parsedconnectpayload_session_id: (a: number) => [number, number];
    readonly parsedconnectpayload_v: (a: number) => [number, number];
    readonly prepareddeployparams_epk: (a: number) => [number, number];
    readonly prepareddeployparams_epk_expire_at: (a: number) => bigint;
    readonly prepareddeployparams_epk_sig: (a: number) => [number, number];
    readonly prepareddeployparams_header_base_64: (a: number) => [number, number];
    readonly prepareddeployparams_index_mod_4: (a: number) => number;
    readonly prepareddeployparams_iss_base_64: (a: number) => [number, number];
    readonly prepareddeployparams_jwk_modulus: (a: number) => [number, number];
    readonly prepareddeployparams_jwk_modulus_expire_at: (a: number) => bigint;
    readonly prepareddeployparams_jwk_update_key: (a: number) => [number, number];
    readonly prepareddeployparams_jwk_update_key_sig: (a: number) => [number, number];
    readonly prepareddeployparams_kid: (a: number) => [number, number];
    readonly prepareddeployparams_name: (a: number) => [number, number];
    readonly prepareddeployparams_proof: (a: number) => [number, number];
    readonly prepareddeployparams_provider: (a: number) => [number, number];
    readonly prepareddeployparams_pub_recovery_key: (a: number) => [number, number];
    readonly prepareddeployparams_pub_recovery_key_sig: (a: number) => [number, number];
    readonly prepareddeployparams_root_provider_certificates: (a: number) => any;
    readonly prepareddeployparams_zkid: (a: number) => [number, number];
    readonly resultgetmirroraddress_address: (a: number) => [number, number];
    readonly resultofaddzkpfactor_address: (a: number) => [number, number];
    readonly resultofaddzkpfactor_message_id: (a: number) => [number, number];
    readonly resultofaddzkpfactor_message_ids: (a: number) => [number, number];
    readonly resultofaddzkpfactor_name: (a: number) => [number, number];
    readonly resultofaddzkpfactor_password_hash: (a: number) => [number, number];
    readonly resultofaddzkpfactor_pubkey: (a: number) => [number, number];
    readonly resultofaddzkpfactor_signing_keys: (a: number) => number;
    readonly resultofblockchainwrite_message_ids: (a: number) => [number, number];
    readonly resultofblockchainwrite_pending_reason: (a: number) => [number, number];
    readonly resultofblockchainwrite_pending_stage: (a: number) => [number, number];
    readonly resultofchecknameavailability_is_available: (a: number) => number;
    readonly resultofchecknameavailability_multifactor_address: (a: number) => [number, number];
    readonly resultofcreatesharedkeysession_app_id: (a: number) => [number, number];
    readonly resultofcreatesharedkeysession_client_dh_public: (a: number) => [number, number];
    readonly resultofcreatesharedkeysession_client_dh_secret: (a: number) => [number, number];
    readonly resultofcreatesharedkeysession_created_at: (a: number) => bigint;
    readonly resultofcreatesharedkeysession_deep_link: (a: number) => [number, number];
    readonly resultofcreatesharedkeysession_description: (a: number) => [number, number];
    readonly resultofcreatesharedkeysession_expires_at: (a: number) => bigint;
    readonly resultofcreatesharedkeysession_payload_b64url: (a: number) => [number, number];
    readonly resultofcreatesharedkeysession_payload_json: (a: number) => [number, number];
    readonly resultofcreatesharedkeysession_session_id: (a: number) => [number, number];
    readonly resultofdeploymultifactor_address: (a: number) => [number, number];
    readonly resultofdeploymultifactor_message_id: (a: number) => [number, number];
    readonly resultofdeploymultifactor_message_ids: (a: number) => [number, number];
    readonly resultofdeploymultifactor_name: (a: number) => [number, number];
    readonly resultofdeploymultifactor_password_hash: (a: number) => [number, number];
    readonly resultofdeploymultifactor_pending_reason: (a: number) => [number, number];
    readonly resultofdeploymultifactor_pending_stage: (a: number) => [number, number];
    readonly resultofdeploymultifactor_phrase: (a: number) => [number, number];
    readonly resultofdeploymultifactor_pubkey: (a: number) => [number, number];
    readonly resultofdeploymultifactor_signing_keys: (a: number) => number;
    readonly resultofdisconnectsession_message_id: (a: number) => [number, number];
    readonly resultofdisconnectsession_profile_address: (a: number) => [number, number];
    readonly resultofdisconnectsession_raw_message_json: (a: number) => [number, number];
    readonly resultofdisconnectsession_updated_session_state_json: (a: number) => [number, number];
    readonly resultofgenminingkeys_deep_link: (a: number) => [number, number];
    readonly resultofgenminingkeys_public: (a: number) => [number, number];
    readonly resultofgenminingkeys_secret: (a: number) => [number, number];
    readonly resultofgetepkexpireat_epk_expire_at: (a: number) => bigint;
    readonly resultofgethistory_data: (a: number) => [number, number];
    readonly resultofgethistory_has_next_page: (a: number) => number;
    readonly resultofgethistory_next_cursor: (a: number) => [number, number];
    readonly resultofgethistory_next_mining_cursor: (a: number) => [number, number];
    readonly resultofgetkeys_public: (a: number) => [number, number];
    readonly resultofgetkeys_secret: (a: number) => [number, number];
    readonly resultofgetminerdetails_address: (a: number) => [number, number];
    readonly resultofgetminerdetails_owner_address: (a: number) => [number, number];
    readonly resultofgetminerdetails_owner_public: (a: number) => any;
    readonly resultofgetmultifactordetails_address: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_candidate_new_owner_pubkey_and_expiration: (a: number) => any;
    readonly resultofgetmultifactordetails_factors_len: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_factors_ordered_by_timestamp: (a: number) => any;
    readonly resultofgetmultifactordetails_force_remove_oldest: (a: number) => number;
    readonly resultofgetmultifactordetails_index_mod_4: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_iss_base_64: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_jwk_modulus_data: (a: number) => any;
    readonly resultofgetmultifactordetails_jwk_modulus_data_len: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_jwk_update_key: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_m_security_cards_len: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_m_transactions_len: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_max_cleanup_txns: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_min_value: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_name: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_owner_pubkey: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_pub_recovery_key: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_root: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_use_security_card: (a: number) => number;
    readonly resultofgetmultifactordetails_wasm_hash: (a: number) => [number, number];
    readonly resultofgetmultifactordetails_white_list_of_address: (a: number) => any;
    readonly resultofgetmultifactordetails_zkid: (a: number) => [number, number];
    readonly resultofgetmultifactorinfo_data: (a: number) => number;
    readonly resultofgetmvmultifactoraddress_address: (a: number) => [number, number];
    readonly resultofgetnativebalances_ecc: (a: number) => any;
    readonly resultofgetnativebalances_popitgame: (a: number) => any;
    readonly resultofgettokensbalances_tokens: (a: number) => any;
    readonly resultofqueryactivesessionsbymultifactor_exhausted_active: (a: number) => number;
    readonly resultofqueryactivesessionsbymultifactor_next_before: (a: number) => [number, number];
    readonly resultofqueryactivesessionsbymultifactor_sessions: (a: number) => any;
    readonly resultofquerysessionmessages_messages: (a: number) => any;
    readonly resultofquerysessionmessages_next_before: (a: number) => [number, number];
    readonly resultofquerysessionmessages_profile_address: (a: number) => [number, number];
    readonly resultofquerysessionmessages_updated_session_state_json: (a: number) => [number, number];
    readonly resultofrequestsetminingkeys_app_id: (a: number) => [number, number];
    readonly resultofrequestsetminingkeys_message_id: (a: number) => [number, number];
    readonly resultofrequestsetminingkeys_owner_public: (a: number) => [number, number];
    readonly resultofrequestsetminingkeys_profile_address: (a: number) => [number, number];
    readonly resultofrequestsetminingkeys_raw_message_json: (a: number) => [number, number];
    readonly resultofrequestsetminingkeys_updated_session_state_json: (a: number) => [number, number];
    readonly resultofrequestsignchallenge_message_id: (a: number) => [number, number];
    readonly resultofrequestsignchallenge_nonce: (a: number) => [number, number];
    readonly resultofrequestsignchallenge_profile_address: (a: number) => [number, number];
    readonly resultofrequestsignchallenge_raw_message_json: (a: number) => [number, number];
    readonly resultofrequestsignchallenge_sent_at: (a: number) => bigint;
    readonly resultofrequestsignchallenge_updated_session_state_json: (a: number) => [number, number];
    readonly resultofsendmessage_aborted: (a: number) => number;
    readonly resultofsendmessage_block_hash: (a: number) => [number, number];
    readonly resultofsendmessage_current_time: (a: number) => [number, number];
    readonly resultofsendmessage_exit_code: (a: number) => number;
    readonly resultofsendmessage_message_hash: (a: number) => [number, number];
    readonly resultofsendmessage_producers: (a: number) => [number, number];
    readonly resultofsendmessage_thread_id: (a: number) => [number, number];
    readonly resultofsendmessage_tx_hash: (a: number) => [number, number];
    readonly resultofvalidatewalletname_error_code: (a: number) => number;
    readonly resultofvalidatewalletname_is_valid: (a: number) => number;
    readonly resultofwaitchallengeresponse_epk_public: (a: number) => [number, number];
    readonly resultofwaitchallengeresponse_event_created_at: (a: number) => bigint;
    readonly resultofwaitchallengeresponse_event_id: (a: number) => [number, number];
    readonly resultofwaitchallengeresponse_nonce: (a: number) => [number, number];
    readonly resultofwaitchallengeresponse_profile_address: (a: number) => [number, number];
    readonly resultofwaitchallengeresponse_raw_message_json: (a: number) => [number, number];
    readonly resultofwaitchallengeresponse_signature: (a: number) => [number, number];
    readonly resultofwaitchallengeresponse_updated_session_state_json: (a: number) => [number, number];
    readonly resultofwaitchallengeresponse_wallet_address: (a: number) => [number, number];
    readonly resultofwaitsetminingkeysrequest_app_id: (a: number) => [number, number];
    readonly resultofwaitsetminingkeysrequest_event_created_at: (a: number) => bigint;
    readonly resultofwaitsetminingkeysrequest_event_id: (a: number) => [number, number];
    readonly resultofwaitsetminingkeysrequest_owner_public: (a: number) => [number, number];
    readonly resultofwaitsetminingkeysrequest_profile_address: (a: number) => [number, number];
    readonly resultofwaitsetminingkeysrequest_raw_message_json: (a: number) => [number, number];
    readonly resultofwaitsetminingkeysrequest_updated_session_state_json: (a: number) => [number, number];
    readonly resultofwaitwallethello_epk_public: (a: number) => [number, number];
    readonly resultofwaitwallethello_event_created_at: (a: number) => bigint;
    readonly resultofwaitwallethello_event_id: (a: number) => [number, number];
    readonly resultofwaitwallethello_nonce: (a: number) => [number, number];
    readonly resultofwaitwallethello_profile_address: (a: number) => [number, number];
    readonly resultofwaitwallethello_raw_message_json: (a: number) => [number, number];
    readonly resultofwaitwallethello_session_state_json: (a: number) => [number, number];
    readonly resultofwaitwallethello_signature: (a: number) => [number, number];
    readonly resultofwaitwallethello_wallet_address: (a: number) => [number, number];
    readonly resultofwaitwallethello_wallet_name: (a: number) => [number, number];
    readonly txdata_created_at: (a: number) => [number, number];
    readonly txdata_id: (a: number) => [number, number];
    readonly txdata_src_name: (a: number) => [number, number];
    readonly txdata_tx_type: (a: number) => [number, number];
    readonly txdata_value: (a: number) => [number, number];
    readonly wallet_add_zkp_factor: (a: number, b: any) => any;
    readonly wallet_add_zkp_factor_with_progress: (a: number, b: any, c: any) => any;
    readonly wallet_buy_shells: (a: number, b: any) => any;
    readonly wallet_change_seed_phrase: (a: number, b: any) => any;
    readonly wallet_check_name_availability: (a: number, b: number, c: number) => any;
    readonly wallet_claim_usdc: (a: number, b: any) => any;
    readonly wallet_complete_zk_login_with_prover_v1: (a: number, b: any) => any;
    readonly wallet_complete_zk_login_with_prover_v1_with_progress: (a: number, b: any, c: any) => any;
    readonly wallet_decode_connect_payload_b64url: (a: number, b: number, c: number) => [number, number, number];
    readonly wallet_del_mining_key: (a: number, b: any) => any;
    readonly wallet_delete_zkp_factor_by_itself: (a: number, b: any) => any;
    readonly wallet_deploy_miner: (a: number, b: any) => any;
    readonly wallet_deploy_miner_with_progress: (a: number, b: any, c: any) => any;
    readonly wallet_deploy_wallet: (a: number, b: any) => any;
    readonly wallet_deploy_wallet_with_progress: (a: number, b: any, c: any) => any;
    readonly wallet_get_epk_expire_at: (a: number, b: any) => any;
    readonly wallet_get_history: (a: number, b: any) => any;
    readonly wallet_get_miner_address: (a: number, b: any) => any;
    readonly wallet_get_miner_details_by_multifactor_address: (a: number, b: number, c: number) => any;
    readonly wallet_get_mirror_address: (a: number, b: any) => [number, number, number];
    readonly wallet_get_multifactor_address: (a: number, b: any) => any;
    readonly wallet_get_multifactor_balances: (a: number, b: any) => any;
    readonly wallet_get_multifactor_data_by_name: (a: number, b: number, c: number) => any;
    readonly wallet_get_multifactor_info: (a: number, b: any) => any;
    readonly wallet_get_my_sell_orders: (a: number, b: any) => any;
    readonly wallet_get_nackl_redeem_rate: (a: number) => any;
    readonly wallet_get_tokens_balances: (a: number, b: any) => any;
    readonly wallet_migrate_tip3_usdc: (a: number, b: any) => any;
    readonly wallet_new: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: number) => [number, number, number];
    readonly wallet_prepare_multifactor_deploy_params: (a: number, b: any) => any;
    readonly wallet_prepare_zk_login_v1: (a: number) => [number, number, number];
    readonly wallet_query_connect_session_messages: (a: number, b: any) => any;
    readonly wallet_redeem_nackl: (a: number, b: any) => any;
    readonly wallet_sell_shells: (a: number, b: any) => any;
    readonly wallet_send_tokens_direct: (a: number, b: any) => any;
    readonly wallet_set_mining_keys: (a: number, b: any) => any;
    readonly wallet_update_zk_id: (a: number, b: any) => any;
    readonly wallet_validate_name: (a: number, b: number, c: number) => [number, number, number];
    readonly zklogincompletewithproverresult_ephemeral_private_key: (a: number) => [number, number];
    readonly zklogincompletewithproverresult_ephemeral_public_key_in_hex: (a: number) => [number, number];
    readonly zklogincompletewithproverresult_ephemeral_secret_key_in_hex: (a: number) => [number, number];
    readonly zklogincompletewithproverresult_header_base64: (a: number) => [number, number];
    readonly zklogincompletewithproverresult_iss_base64_details: (a: number) => number;
    readonly zklogincompletewithproverresult_max_epoch: (a: number) => bigint;
    readonly zklogincompletewithproverresult_zk_proof_compressed: (a: number) => [number, number];
    readonly zklogincompletewithproverresult_zkid: (a: number) => [number, number];
    readonly zkloginprepareresult_ephemeral_private_key: (a: number) => [number, number];
    readonly zkloginprepareresult_max_epoch: (a: number) => bigint;
    readonly zkloginprepareresult_nonce: (a: number) => [number, number];
    readonly zkloginprepareresult_randomness: (a: number) => [number, number];
    readonly tc_create_context: (a: number) => number;
    readonly tc_destroy_string: (a: number) => void;
    readonly tc_read_string: (a: number, b: number) => void;
    readonly tc_request: (a: number, b: number, c: number, d: number, e: number) => void;
    readonly tc_request_ptr: (a: number, b: number, c: number, d: number, e: number) => void;
    readonly tc_request_sync: (a: number, b: number, c: number) => number;
    readonly tc_destroy_context: (a: number) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h321bf97868035313: (a: number, b: number, c: any) => [number, number];
    readonly wasm_bindgen__convert__closures_____invoke__h3bb2fb1b11ee80c5: (a: number, b: number, c: any, d: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h925b4af5ea1f93bb: (a: number, b: number, c: any) => [number, number];
    readonly wasm_bindgen__convert__closures_____invoke__h217ac0f026a0e79e: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h217ac0f026a0e79e_327: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h217ac0f026a0e79e_329: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__he543d5900fbe76e3: (a: number, b: number, c: any) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h16e37a3982040429: (a: number, b: number) => void;
    readonly wasm_bindgen__convert__closures_____invoke__h876d8efedbc4c57a: (a: number, b: number) => void;
    readonly wasm_bindgen__convert__closures_____invoke__hb110da9538c22f83: (a: number, b: number) => void;
    readonly wasm_bindgen__convert__closures_____invoke__hced6575db1860eef: (a: number, b: number) => void;
    readonly __wbindgen_malloc: (a: number, b: number) => number;
    readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
    readonly __wbindgen_exn_store: (a: number) => void;
    readonly __externref_table_alloc: () => number;
    readonly __wbindgen_externrefs: WebAssembly.Table;
    readonly __wbindgen_free: (a: number, b: number, c: number) => void;
    readonly __wbindgen_destroy_closure: (a: number, b: number) => void;
    readonly __externref_table_dealloc: (a: number) => void;
    readonly __externref_drop_slice: (a: number, b: number) => void;
    readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

/**
 * Instantiates the given `module`, which can either be bytes or
 * a precompiled `WebAssembly.Module`.
 *
 * @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
 *
 * @returns {InitOutput}
 */
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
 * If `module_or_path` is {RequestInfo} or {URL}, makes a request and
 * for everything else, calls `WebAssembly.instantiate` directly.
 *
 * @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
 *
 * @returns {Promise<InitOutput>}
 */
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
