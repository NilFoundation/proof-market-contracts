import {ethers} from "hardhat";

async function main() {
    const lock = await ethers.deployContract("ProofMarket");
    await lock.waitForDeployment();
    console.log(
        `Contract ProofMarket deployed to ${lock.target}`
    );
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
