import { ethers } from "hardhat";

async function main() {
    //await testLayerzero();
    await testCCIP();
}

async function testCCIP() {
    const bridge = await ethers.getContractAt("AvUSDBridging", "0xb6a98600a66C35985958C4DDA1599A4C15Ff9D70");
    const value = await bridge.quoteSendFeeWithCCIP(
        "5224473277236331295",
        "0x19596e1D6cd97916514B5DBaA4730781eFE49975",
        "15000000000000000000",
        true
    );
    console.log(`fee: ${value}`);
    const tx = await bridge.sendWithCCIP(
        "5224473277236331295",
        "0x19596e1D6cd97916514B5DBaA4730781eFE49975",
        "15000000000000000000",
        true,
        { value }
    );
    await tx.wait();
    console.log(`Done: ${tx.hash}`);
}

async function testLayerzero() {
    const bridge = await ethers.getContractAt("AvUSDBridging", "0xb6a98600a66C35985958C4DDA1599A4C15Ff9D70");
    const value = await bridge.quoteSendFeeWithLayerzero(
        40232,
        "0x19596e1D6cd97916514B5DBaA4730781eFE49975",
        "25000000000000000000",
        true,
        "0x000301001101000000000000000000000000001e8480"
    );
    console.log(`fee: ${value}`);
    const tx = await bridge.sendWithLayerzero(
        40232,
        "0x19596e1D6cd97916514B5DBaA4730781eFE49975",
        "25000000000000000000",
        true,
        "0x000301001101000000000000000000000000001e8480",
        { value }
    );
    await tx.wait();
    console.log(`Done: ${tx.hash}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
