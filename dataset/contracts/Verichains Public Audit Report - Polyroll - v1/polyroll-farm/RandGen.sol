// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "https://github.com/smartcontractkit/chainlink/blob/0964ca290565587963cc4ad8f770274f5e0d9e9d/evm-contracts/src/v0.6/VRFConsumerBase.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";
import "./libs/IMasterChef.sol";

/**
 * RandGen is the contract that governs the requesting and receiving of random number from Chainlink VRF oracle.
 * v02 notes: contract has separated fulfillRandomness from settleLottery because Chainlink Coordinator has a very low gas limit.
 */
contract RandGen is VRFConsumerBase, Ownable {
    using SafeERC20 for IERC20;

    address public constant VRF_COORDINATOR = 0x3d2341ADb2D31f1c5530cDC622016af293177AE0;
    address public constant LINK_TOKEN = 0xb0897686c545045aFc77CF20eC7A532E3120E0F1;
    bytes32 public constant KEY_HASH = 0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da;
    uint public fee = 10 ** 18 * 0.0001; // 0.0001 LINK (Varies by network)

    bytes32 public requestId;
    uint public randomness;

    IMasterChef public masterChef;

    constructor() VRFConsumerBase(VRF_COORDINATOR, LINK_TOKEN) public {}

    modifier onlyMasterChef() {
        require(msg.sender == address(masterChef), "Only MasterChef can call this function");
        _;
    }

    function setMasterChef(IMasterChef _masterChef) external onlyOwner {
        masterChef = _masterChef;
    }

    function setFee(uint _fee) external onlyOwner {
        fee = _fee;
    }

    // Requests randomness from a user-provided seed
    function getRandomNumber(uint _userProvidedSeed) external onlyMasterChef returns (bytes32 _requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK in contract.");
        return requestRandomness(KEY_HASH, fee, _userProvidedSeed);
    }

    // Callback function used by VRF Coordinator
    function fulfillRandomness(bytes32 _requestId, uint _randomness) internal override {
        requestId = _requestId;
        randomness = _randomness;
    }

    // SettleLottery function is seperated from fulfillRandomness because 
    // Chainlink VRF has a very low gas limit and we need to call settleLottery and pay gas fees ourselves.
    function settleLottery() external onlyOwner {
        masterChef.settleLottery(requestId, randomness);
    }

    // Withdraw LINK and other ERC20 tokens sent here by mistake
    function withdrawTokens(address token_address) external onlyOwner {
        IERC20(token_address).safeTransfer(owner(), IERC20(token_address).balanceOf(address(this)));
    }
}
