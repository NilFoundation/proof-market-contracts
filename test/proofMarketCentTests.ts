import {loadFixture} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {ethers} from "hardhat";
import {expect} from "chai";

describe("ProofMarket contract", function () {
    async function deployFixture() {
        const [owner, otherAccount] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("ProofMarket");
        const contract = await contractFactory.deploy();
        return {contract, owner, otherAccount};
    }

    describe("Deployment", function () {
        it("Should set the right admin", async function () {
            const {contract, owner} = await loadFixture(deployFixture);
            expect(await contract.admin()).to.equal(owner.address);
        });
    });

    describe("Deposit", function () {
        it("Should deposit and emit event", async function () {
            const {contract, owner, otherAccount} = await loadFixture(deployFixture);
            await expect(await contract.connect(otherAccount).deposit({value: 1000}))
                .to.emit(contract, 'Deposit')
                .withArgs(otherAccount.address, 1000);
            expect(await contract.balanceOf(otherAccount.address)).to.equal(1000);
        });

        it("Should allow admin to withdraw and emit event", async function () {
            const {contract, owner, otherAccount} = await loadFixture(deployFixture);
            await contract.connect(otherAccount).deposit({value: 1000});
            await expect(contract.connect(owner).withdraw(otherAccount.address, 500))
                .to.emit(contract, 'Withdraw')
                .withArgs(otherAccount.address, 500);
            const finalBalance = await contract.balanceOf(otherAccount.address);
            expect(finalBalance).to.equal(500);
        });

        it("Should fail if non-admin tries to withdraw", async function () {
            const {contract, owner, otherAccount} = await loadFixture(deployFixture);
            await contract.connect(otherAccount).deposit({value: 1000});
            await expect(contract.connect(otherAccount).withdraw(otherAccount.address, 1000))
                .to.be.revertedWith("Only the admin can perform this action");
        });

        it("Should fail if withdraw amount exceeds balance", async function () {
            const {contract, owner, otherAccount} = await loadFixture(deployFixture);
            await contract.connect(otherAccount).deposit({value: 1000});
            await expect(contract.connect(owner).withdraw(otherAccount.address, 1001))
                .to.be.revertedWith("Insufficient balance");
        });
    });
});
