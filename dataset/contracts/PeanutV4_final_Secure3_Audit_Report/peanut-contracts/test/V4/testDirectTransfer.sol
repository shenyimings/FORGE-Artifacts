// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@forge-std/Test.sol";
import "../../src/V4/PeanutV4.sol";
import "../../src/util/ERC20Mock.sol";
import "../../src/util/ERC721Mock.sol";
import "../../src/util/ERC1155Mock.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract PeanutV4Test is Test, ERC1155Holder, ERC721Holder {
    PeanutV4 public peanutV4;
    ERC20Mock public testToken;
    ERC721Mock public testToken721;
    ERC1155Mock public testToken1155;

    // a dummy private/public keypair to test withdrawals
    address public constant PUBKEY20 = address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);
    bytes32 public constant PRIVKEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    function setUp() public {
        console.log("Setting up test");
        peanutV4 = new PeanutV4(address(0));
        testToken = new ERC20Mock();
        testToken721 = new ERC721Mock();
        testToken1155 = new ERC1155Mock();
    }

    // make contract payable
    receive() external payable {}

    function testDirectTransferERC721(uint64 tokenId) public {
        testToken721.mint(address(this), tokenId);
        bytes20 pubKey20Bytes = bytes20(PUBKEY20);
        testToken721.safeTransferFrom(address(this), address(peanutV4), tokenId, abi.encode(pubKey20Bytes));

        PeanutV4.Deposit memory deposit = peanutV4.getDeposit(peanutV4.getDepositCount() - 1);
        assertEq(deposit.pubKey20, PUBKEY20, "Decoded address does not match the test public key");
    }

    function testDirectTransferERC1155(uint64 tokenId, uint64 amount) public {
        testToken1155.mint(address(this), tokenId, amount, "");
        bytes20 pubKey20Bytes = bytes20(PUBKEY20);
        testToken1155.safeTransferFrom(address(this), address(peanutV4), tokenId, amount, abi.encode(pubKey20Bytes));

        PeanutV4.Deposit memory deposit = peanutV4.getDeposit(peanutV4.getDepositCount() - 1);
        assertEq(deposit.pubKey20, PUBKEY20, "Decoded address does not match the test public key");
    }

    struct TokenData {
        uint16 tokenId;
        uint16 amount;
    }

    // V5
    function testDirectTransferBatchERC1155(TokenData[] memory tokens) public {
        // assume TokenData array is not empty
        vm.assume(tokens.length > 0);
        // assume amount of each token is greater than 0
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.assume(tokens[i].amount > 0);
            vm.assume(tokens[i].tokenId > 0);
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            testToken1155.mint(address(this), tokens[i].tokenId, tokens[i].amount, "");
        }

        bytes20 pubKey20Bytes = bytes20(PUBKEY20);
        // bytes32 pubKey32Bytes = bytes32(uint256(uint160(PUBKEY20)));

        // Create a new bytes array of size tokens.length * 32
        bytes memory data = new bytes(tokens.length * 32);

        // Fill the data array with the pubKey32Bytes encoded into a 32-byte array for each token
        bytes memory encodedPubKey = abi.encode(pubKey20Bytes);
        for (uint256 i = 0; i < tokens.length; i++) {
            for (uint256 j = 0; j < 32; j++) {
                data[(i * 32) + j] = encodedPubKey[j];
            }
        }

        // Prepare tokenIds and amounts for safeBatchTransferFrom
        uint256[] memory tokenIds = new uint256[](tokens.length);
        uint256[] memory amounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            tokenIds[i] = tokens[i].tokenId;
            amounts[i] = tokens[i].amount;
        }

        testToken1155.safeBatchTransferFrom(address(this), address(peanutV4), tokenIds, amounts, data);

        for (uint256 i = 0; i < tokens.length; i++) {
            console.log(peanutV4.getDepositCount());
            PeanutV4.Deposit memory deposit = peanutV4.getDeposit(peanutV4.getDepositCount() - 1 - i);
            console.log(deposit.pubKey20);
            console.log(PUBKEY20);
            assertEq(deposit.pubKey20, PUBKEY20, "Decoded address does not match the test public key");
        }
    }
}
