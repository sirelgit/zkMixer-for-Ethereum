// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./verifier.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";


contract Laundeth is ReentrancyGuard, Ownable {
    using Address for address payable;
    Verifier public verifyProof;

    uint256 public constant amount = 1 ether;
    uint256 public poolBalance; 

    mapping(bytes32 => bool) public history_roots;
    mapping(bytes32 => bool) public commitments;    
    mapping(bytes32 => bool) public nullifiersHashes;

    event RootUpdated(bytes32 newRoot);
    event Deposit(bytes32 commitment);
    event Withdraw(bytes32 indexed nullifierHash);
    event ExtraETHSwept(address indexed to, uint256 amount, address indexed by);



    constructor(address verifier, address _owner) {
        require(_owner != address(0), "Zero address - Owner constructor");
        require(verifier != address(0), "Zero address - Verifier constructor");
        transferOwnership(_owner);
        verifyProof = Verifier(verifier);
    }
    

    function deposit(bytes32 commitment) external payable {
        require(msg.value == amount, "Invalid amount");
        require(!commitments[commitment], "Commitment already used");

        commitments[commitment] = true;
        poolBalance += amount;
        
        emit Deposit(commitment);
        
    }

    function updateRoot(bytes32 newRoot) external onlyOwner {
        require(!history_roots[newRoot], "Root already exists");
        history_roots[newRoot] = true;
        emit RootUpdated(newRoot);
    }

    function buildInput(uint256[8] calldata root, uint256[8] calldata nullifier) private pure returns (uint256[16] memory) {
        uint256[16] memory input;
        for (uint256 i = 0; i < 8; i++) {
            input[i] = root[i];
            input[i + 8] = nullifier[i];
        }
        return input;
    }


function reconstructBytes32FromU32Array(uint256[8] calldata arr) private pure returns (bytes32 result) {
    for (uint256 i = 0; i < 8; i++) {
        require(arr[i] <= type(uint32).max, "Value exceeds uint32 range");
        result |= bytes32(arr[i] << (224 - i * 32));
    }
}


function rootMatch(uint256[8] calldata rootU32, bytes32 validRoot) private pure returns (bool) {

    bytes32 root = reconstructBytes32FromU32Array(rootU32);

    return root == validRoot;

}

    function withdraw(
        address payable to,
        Verifier.Proof calldata proof,
        uint256[8] calldata root_in_proof,
        uint256[8] calldata nullifier_in_proof,
        bytes32 validRoot

    ) external nonReentrant {
        require(to != address(0), "Cannot withdraw to zero address");
        require(poolBalance >= amount, "Insufficient funds in pool");
        require(history_roots[validRoot], "Invalid root");
        
        bytes32 nullifierHash = reconstructBytes32FromU32Array(nullifier_in_proof);
        require(!nullifiersHashes[nullifierHash], "Nullifier already used");
        
        require(rootMatch(root_in_proof, validRoot), "Root mismatch");
        
        uint256[16] memory input = buildInput(root_in_proof, nullifier_in_proof);
        require(verifyProof.verifyTx(proof, input), "Invalid proof");

        nullifiersHashes[nullifierHash] = true;
        poolBalance -= amount;
        emit Withdraw(nullifierHash);

        to.sendValue(amount);
    }

    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }

    fallback() external payable {
        revert("Direct ETH transfers not allowed");
    }

    function sweepExtraETH(address payable to) external onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > poolBalance, "No extra ETH to sweep");
        uint256 extra = contractBalance - poolBalance;
        emit ExtraETHSwept(to, extra, msg.sender);
        to.sendValue(extra);
    }
}
