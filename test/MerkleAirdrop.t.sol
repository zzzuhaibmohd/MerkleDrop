//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {BagelToken} from "../src/BagelToken.sol";

contract MerkleAirdropTest is Test {
    MerkleAirdrop public airdrop;
    BagelToken public token;

    bytes32 public constant ROOT = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 public constant AMOUNT_TO_CLAIM = 25 ether;
    uint256 public constant AMOUNT_TO_MINT = 100 ether;
    address gasPayer;
    address user;
    uint256 userPrivKey;

    bytes32 public proofOne = 0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 public proofTwo = 0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] public PROOF = [proofOne, proofTwo];

    function setUp() public {
        token = new BagelToken();
        airdrop = new MerkleAirdrop(ROOT, token);
        token.mint(address(airdrop), AMOUNT_TO_MINT);
        // mint tokens to user
        (user, userPrivKey) = makeAddrAndKey("user");
        gasPayer = makeAddr("gasPayer");
    }

    function test_userCanClaimAirdrop() public {
        uint256 startingBalance = token.balanceOf(user);

        bytes32 digest = airdrop.getMessageHash(user, AMOUNT_TO_CLAIM);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivKey, digest);

        vm.prank(gasPayer);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);

        uint256 endingBalance = token.balanceOf(user);
        assertEq(endingBalance, startingBalance + AMOUNT_TO_CLAIM);
    }

    function test_userCannotClaimAirdropTwice() public {
        test_userCanClaimAirdrop();

        bytes32 digest = airdrop.getMessageHash(user, AMOUNT_TO_CLAIM);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivKey, digest);

        vm.expectRevert(MerkleAirdrop.MerkleAirdrop__AlreadyClaimed.selector);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);
    }

    function test_userCannotClaimAirdropWithInvalidSignature() public {
        bytes32 digest = airdrop.getMessageHash(user, AMOUNT_TO_CLAIM);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivKey, digest);

        vm.expectRevert(MerkleAirdrop.MerkleAirdrop__InvalidSignature.selector);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v + 1, r, s);
    }

    function test_userCannotClaimAirdropWithInvalidProof() public {
        bytes32 digest = airdrop.getMessageHash(user, AMOUNT_TO_CLAIM);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivKey, digest);

        bytes32[] memory invalidProof = new bytes32[](2);
        invalidProof[0] = 0x4fd31fee0e75780cd67704fbc43caee70fddcaa43631e2e1bc9fb233fada2394;
        invalidProof[1] = 0x81f0e530b56872b6fc3e10f8873804230663f8407e21cef901b8aeb06a25e5e2;

        vm.expectRevert(MerkleAirdrop.MerkleAirdrop__InvalidProof.selector);
        airdrop.claim(user, AMOUNT_TO_CLAIM, invalidProof, v, r, s);
    }

    function test_getterFunctions() public view {
        assertEq(airdrop.getMerkleRoot(), ROOT);
        assertEq(address(airdrop.getAirdropToken()), address(token));
    }
}
