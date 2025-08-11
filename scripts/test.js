const Laundeth = artifacts.require("Laundeth");
const { exec } = require("child_process");
const util = require('util');
const fs = require('fs');
const path = require('path');

const execAsync = util.promisify(exec);


function ensureHexPrefix(value) {
  if (typeof value !== 'string') {
  throw new Error("Value is not a string");
  }
  return value.startsWith("0x") ? value : "0x" + value;
}

module.exports = async function (callback) {
  try {
    const accounts = await web3.eth.getAccounts();
    const owner = accounts[0];
    const depositor = accounts[1];
    const withdrawer = accounts[2];

    const laundeth = await Laundeth.deployed();

    const amount = web3.utils.toWei("1", "ether");

// On deposit request do:
    console.log("Performing deposit");
    try{
      console.log("🔄 Generating commitment...");

      await execAsync('cd Zokrates && python3 generate_commit.py');
      console.log("✅ Commitment generated!");

      
      const filePath1 = path.join(__dirname, '../Zokrates/commitmentTest.json');
      const data1 = fs.readFileSync(filePath1, 'utf8');
      const commitmentTest = JSON.parse(data1);
      const firstCommitment = commitmentTest[0];
      const commitmentValue = String(firstCommitment.commitment);
      const commitmentTestHex = ensureHexPrefix(commitmentValue);
      
      await laundeth.deposit(commitmentTestHex, { from: depositor, value: amount });
  console.log("Deposit completed");
    } catch (error) {
  console.error("Error during commitment generation:", error);
      return;
    }
    
// End deposit



// On withdrawal request do:
    let newRoot; 
    
    try{
  console.log("🔄 Generating root...");
      await execAsync('cd Zokrates && python3 generate_tree.py > input.txt');
      
      const filePath = path.join(__dirname, '../Zokrates/commitmentHistory.json');
      const data = fs.readFileSync(filePath, 'utf8');
      const commitments = JSON.parse(data);
      const lastCommitment = commitments[commitments.length - 1];
      
      newRoot = ensureHexPrefix(lastCommitment.rootHash);
      await laundeth.updateRoot(newRoot, { from: owner });
  console.log("Initial root registered");
      
  console.log("🔄 Generating ZK proof...");
      await execAsync('cd Zokrates && xargs zokrates compute-witness -a < input.txt');
      await execAsync('cd Zokrates && zokrates generate-proof');
  console.log("✅ ZK proof generated!");
      
    } catch (error) {
  console.error("Error during root generation:", error);
      return;
    }

    const filePath2 = path.join(__dirname, '../Zokrates/proof.json');
    const data2 = fs.readFileSync(filePath2, 'utf8');
    const proofJson = JSON.parse(data2);

      const proof = {
      a: [proofJson.proof.a[0], proofJson.proof.a[1]],
      b: [
        [proofJson.proof.b[0][0], proofJson.proof.b[0][1]],
        [proofJson.proof.b[1][0], proofJson.proof.b[1][1]],
      ],
      c: [proofJson.proof.c[0], proofJson.proof.c[1]],
    };

    

    const inputs = proofJson.inputs;

  console.log("Performing withdrawal");
    const input1 = inputs.slice(0, 8);
    const input2 = inputs.slice(8, 16);


    for (let i = 0; i < input1.length; i++) {
      input1[i] = web3.utils.toBN(input1[i]);
    }
    for (let i = 0; i < input2.length; i++) {
      input2[i] = web3.utils.toBN(input2[i]);
    }

    await laundeth.withdraw(
      withdrawer,
      proof,
      input1,
      input2,
      newRoot,
      { from: withdrawer }
    );
    
  console.log("Withdrawal completed");

  } catch (error) {
    console.error(error);
  }

  callback();
};
