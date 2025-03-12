// SPDX-License-Identifier: Ulicense
pragma solidity ^0.8.6;

contract RewardClaim {
    address public immutable vestingAddress;
    address public immutable tokenAddress;

    uint256 public claimedRewards;

    mapping(address => bool) public alreadyClaimed;

    uint256[] tokens;

    constructor(address vesting, address token) {
        vestingAddress = vesting;
        tokenAddress = token;
        owner = msg.sender;
    }

    function claimReward() external {
        require(!alreadyClaimed[msg.sender], "Already claimed!");
        uint256 amt = Ivesting(vestingAddress).bonus(msg.sender);
        require(amt > 0, "No reward to claim!");
        alreadyClaimed[msg.sender] = true;
        uint256 i;
        for (i; i < amt; i++) {
            uint256 tokenId = tokens[tokens.length - 1];
            tokens.pop();

            Ierc721(tokenAddress).transferFrom(
                address(this),
                msg.sender,
                tokenId
            );
            claimedRewards++;
        }
    }

    function registerRewards(uint256[] calldata rewards) external onlyOwner {
        uint256 i;
        uint256 len = rewards.length;
        for (i; i < len; i++) {
            tokens.push(rewards[i]);
        }
    }

    function rewardsLeft() external view returns (uint256) {
        return tokens.length;
    }

    function nextReward() external view returns (uint256) {
        return tokens[tokens.length - 1];
    }

    //
    // god mode
    //
    address public owner;
    address public newOwner;
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    function giveOwnership(address _newOwner) external onlyOwner {
        newOwner = _newOwner;
    }

    // new owner need to accept ownership
    function acceptOwnership() external {
        require(msg.sender == newOwner, "You are not New Owner");
        newOwner = address(0);
        owner = msg.sender;
    }

    function rescueERC20(address _token) external onlyOwner {
        uint256 amt = Ierc20(_token).balanceOf(address(this));
        require(amt > 0, "Nothing to rescue");
        Ierc20(_token).transfer(owner, amt);
    }

    function rescueETH() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function rescueNFT(address token, uint256 id) external onlyOwner {
        Ierc721(token).transferFrom(address(this), msg.sender, id);
    }
}

interface Ivesting {
    function bonus(address user) external view returns (uint256);
}

interface Ierc721 {
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

interface Ierc20 {
    function transfer(address to, uint256 tokenId) external;

    function balanceOf(address user) external returns (uint256);
}
