const Verifier = artifacts.require("Verifier");
const Laundeth = artifacts.require("Laundeth");

module.exports = async function (deployer, network, accounts) {
  try {;
    await deployer.deploy(Verifier, { gas: 8000000 });
    const verifierInstance = await Verifier.deployed();
    await deployer.deploy(Laundeth, verifierInstance.address, accounts[0]);
  } catch (error) {
    throw error;
  }
};
