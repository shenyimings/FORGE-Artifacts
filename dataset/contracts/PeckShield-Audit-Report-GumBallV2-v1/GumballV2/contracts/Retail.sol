// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Owned {
    address public owner;
    address public nominatedOwner;

    constructor(address _owner) {
        require(_owner != address(0), "Owner address cannot be 0");
        owner = _owner;
        emit OwnerChanged(address(0), _owner);
    }

    function nominateNewOwner(address _owner) external onlyOwner {
        nominatedOwner = _owner;
        emit OwnerNominated(_owner);
    }

    function acceptOwnership() external {
        require(msg.sender == nominatedOwner, "You must be nominated before you can accept ownership");
        emit OwnerChanged(owner, nominatedOwner);
        owner = nominatedOwner;
        nominatedOwner = address(0);
    }

    modifier onlyOwner {
        _onlyOwner();
        _;
    }

    function _onlyOwner() private view {
        require(msg.sender == owner, "Only the contract owner may perform this action");
    }

    event OwnerNominated(address newOwner);
    event OwnerChanged(address oldOwner, address newOwner);
}

interface IERC20BondingCurve {
    function BASE_TOKEN() external view returns (address);
    function borrowMax() external;
}

interface IGumbar {
    function depositNFT(uint256[] memory _id) external;
    function getReward() external;
}

interface IRetailRewarder {
    function deposit(address account, uint256 amount) external;
    function notifyRewardAmount(address _rewardsToken, uint256 reward) external;
}

contract Retail is Owned {

    uint256 public immutable AMOUNT = 1e18;

    address public immutable GBT; // ERC20BondingCurve
    address public immutable XGBT; // Gumbar
    address public immutable GNFT; // Gumball
    address public immutable BASE; // Base token

    address public retailRewarder;
    mapping(address => bool) public rewardTokens; 

    // Total staked
    uint public totalSupply;
    // User address => staked amount
    mapping(address => uint) public balanceOf;
    // User address => gNFTs redeemed
    mapping(address => uint[]) public redemptions;

    constructor(address _owner, 
                address _GBT, 
                address _XGBT,
                address _GNFT
    ) Owned(_owner) {
        GBT = _GBT;
        XGBT = _XGBT;
        GNFT = _GNFT;
        BASE = IERC20BondingCurve(GBT).BASE_TOKEN();
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) public view returns (bytes4) {
        return IERC721Receiver(address(this)).onERC721Received.selector;
    }

    function redeem(uint _id) external {
        address account = msg.sender;

        redemptions[account].push(_id);
        balanceOf[account] = balanceOf[account] + AMOUNT;
        totalSupply = totalSupply + AMOUNT;

        uint[] memory temp = new uint[](1);
        temp[0] = _id;

        IERC721(GNFT).safeTransferFrom(account, address(this), _id);
        IERC721(GNFT).approve(XGBT, _id);
        IGumbar(XGBT).depositNFT(temp);
        IRetailRewarder(retailRewarder).deposit(account, AMOUNT);
        
        emit Redeemed(account, _id);
    }

    function claimFeesToRewarder() external {
        IGumbar(XGBT).getReward();
        uint256 balanceGBT = IERC20(GBT).balanceOf(address(this));
        uint256 balanceBASE = IERC20(BASE).balanceOf(address(this));
        if (balanceGBT > 0) {

            IERC20(GBT).approve(retailRewarder, balanceGBT);
            IRetailRewarder(retailRewarder).notifyRewardAmount(GBT, balanceGBT);
            emit RewardStarted(GBT, balanceGBT);
        }
        if (balanceBASE > 0) {

            IERC20(BASE).approve(retailRewarder, balanceBASE);
            IRetailRewarder(retailRewarder).notifyRewardAmount(BASE, balanceBASE);
            emit RewardStarted(BASE, balanceBASE);
        }
    }

    function collect() external {
        IERC20BondingCurve(GBT).borrowMax();
        uint256 balanceBASE = IERC20(BASE).balanceOf(address(this));
        IERC20(BASE).transfer(owner, balanceBASE);
        emit Collected(owner, balanceBASE);
    }

    function setRetailRewarder(address _rewarder) external onlyOwner {
        retailRewarder = _rewarder;
    }

    /* ========== EVENTS ========== */

    event Redeemed(address indexed account, uint256 id);
    event RewardStarted(address indexed rewardsToken, uint256 reward);
    event Collected(address indexed user, uint256 amount);

}