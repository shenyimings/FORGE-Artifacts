// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface vEmpireGame {
    function getPlayersForAirdrop() external view returns (address[] memory);
}

contract RandomNumberConsumer is VRFConsumerBase, Context, Ownable {
    using SafeMath for uint256;

    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;
    address public gameAddress;
    address public rewardToken;

    modifier onlyGame() {
        require(gameAddress == _msgSender(), "Caller is not Game");
        _;
    }

    /**
     * Constructor inherits VRFConsumerBase
     *
     * Network: Kovan
     * Chainlink VRF Coordinator address: 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9
     * LINK token address:                0xa36085F69e2889c224210F603D836748e7dC0088
     * Key Hash: 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4
     */
    constructor(address _rewardToken, address _gameAddress)
        public
        VRFConsumerBase(
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
            0xa36085F69e2889c224210F603D836748e7dC0088 // LINK Token
        )
    {
        require(_rewardToken != address(0), "Invalid _rewardToken address");
        require(_gameAddress != address(0), "Invalid _gameAddress address");
        rewardToken = _rewardToken;
        gameAddress = _gameAddress;
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10**18; // 0.1 LINK (Varies by network)
    }

    function setGameAddress(address _gameAddress) public onlyOwner {
    	require(_gameAddress != address(0), "Invalid _gameAddress address");
        gameAddress = _gameAddress;
    }
    
    function setRewardAddress(address _rewardToken) public onlyOwner {
    	require(_rewardToken != address(0), "Invalid _rewardToken address");
        rewardToken = _rewardToken;
    }

    /**
     * Requests randomness
     */
    function getRandomNumber() public onlyOwner returns (bytes32 requestId) {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
        return requestRandomness(keyHash, fee);
    }

    function expand(uint256 randomValue, uint256 n)
        public
        view
        onlyOwner
        returns (uint256[] memory expandedValues)
    {
        expandedValues = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            expandedValues[i] = uint256(keccak256(abi.encode(randomValue, i)));
        }
        return expandedValues;
    }

    /**
     * Callback function used by VRF Coordinator=
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        randomResult = randomness;
    }
    
    function pickWinner(uint256 _lotteryAmount) public onlyOwner {
        require(
            vEmpireGame(gameAddress).getPlayersForAirdrop().length > 0,
            "No addresses for airdrop lottery"
        );

        uint256 arrayIndex = SafeMath.mod(
            randomResult,
            vEmpireGame(gameAddress).getPlayersForAirdrop().length
        );

        IERC20(rewardToken).transfer(
            vEmpireGame(gameAddress).getPlayersForAirdrop()[arrayIndex],
            _lotteryAmount
        );
    }

    /**
    * @dev Allows the oracle operator to withdraw their LINK
    * @param _recipient is the address the funds will be sent to
    * @param _amount is the amount of LINK transferred from the Coordinator contract
    */
    function withdraw(address _recipient, uint256 _amount)
        external
        onlyOwner
    {
        require(_recipient != address(0), "Invalid _recipient address");
        require(LINK.balanceOf(address(this)) >= _amount, "Can't withdraw more than balance");
        assert(LINK.transfer(_recipient, _amount));
    }

    /**
     * @dev Used only by admin or owner, used to withdraw locked VEMP tokens in emergency
     *
     * @param _to address of VEMP tokens receiver
     * @param _amount amount of VEMP and must be less than total locked amount
     */
    function emergencyWithdrawVempTokens(address _to, uint256 _amount)
        public
        onlyOwner
    {
        require(_to != address(0), "Invalid _to address");
        uint256 vempBal = IERC20(rewardToken).balanceOf(address(this));
        require(vempBal >= _amount, "Insufficiently amount");
        bool status = IERC20(rewardToken).transfer(_to, _amount);
        require(status, "Token transfer failed");
    }
}
