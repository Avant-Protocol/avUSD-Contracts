import { Options } from "@layerzerolabs/lz-v2-utilities";

async function main() {
    const GAS_LIMIT = 2000000; // Gas limit for the executor
    const MSG_VALUE = 0; // msg.value for the lzReceive() function on destination in wei
    const options = Options.newOptions();
    options.addExecutorLzReceiveOption(GAS_LIMIT, MSG_VALUE);
    console.log(options.toHex());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
