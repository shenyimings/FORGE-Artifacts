// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/V4/PeanutV4.sol";
import "../../src/util/ERC20Mock.sol";
import "../../src/util/ERC721Mock.sol";
import "../../src/util/ERC1155Mock.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract TestSigWithdrawEther is Test {
    PeanutV4 public peanutV4;

    // sample inputs
    address _pubkey20 = 0xa693Ce8915c050E8fB6a91097de8f4C96D13192A;
    address _recipientAddress = 0x6B3751c5b04Aa818EA90115AA06a4D9A36A16f02;
    // bytes32 _recipientAddressHash = 0x43fcd47dd82c4fd18ae2f2d674b46273c645331bdfdf312badfe3592d43e58cd;
    bytes32 _recipientAddressHashEip191 = 0x9192b2026401b2d52667b8458bb54cc7847746441d70cd1bc63fc875a5b4f54a;
    bytes public signature =
        hex"997928768fcdb48faa1af08cdd9bb5e694d51a8d1495ec9b464ea1b10d20501119f1eb0cca20bc684c5d6b9663191181b68e159e08a06dfc29d17693ed4d8b981b";

    receive() external payable {} // necessary to receive ether

    function setUp() public {
        console.log("Setting up test");
        peanutV4 = new PeanutV4(address(0));
    }

    // test sender withdrawal of ERC20
    function testSigWithdrawEther(uint64 amount) public {
        vm.assume(amount > 0);
        uint256 depositIdx = peanutV4.makeDeposit{value: amount}(address(0), 0, amount, 0, _pubkey20);
        peanutV4.withdrawDeposit(depositIdx, _recipientAddress, _recipientAddressHashEip191, signature);
    }
}
