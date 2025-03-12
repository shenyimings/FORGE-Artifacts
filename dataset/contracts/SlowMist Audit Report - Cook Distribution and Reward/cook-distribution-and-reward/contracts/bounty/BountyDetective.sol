pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

/**
 * @title Bounty Detective
 * @dev Bounty Detective address claim the tokens in the contract 180 days after TGE.
 */
contract BountyDetective {
    using SafeERC20 for IERC20;

    event Claim(address claimer, uint256 amount);

    IERC20 private token;

    uint256 private unlockTimestamp;
    address private detectiveAddress;

    constructor(
        IERC20 _token,
        uint256 _unlockTimestamp,
        address _detectiveAddress
    ) public {
        token = _token;
        unlockTimestamp = _unlockTimestamp;
        detectiveAddress = _detectiveAddress;
    }

    function getUnlockTimestamp() public view returns (uint256) {
        return unlockTimestamp;
    }

    function getDetectiveAddress() public view returns (address) {
        return detectiveAddress;
    }

    function getTokenAddress() public view returns (IERC20) {
        return token;
    }

    function getVestingToken() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getClaimableToken() public view returns (uint256) {
        if (block.timestamp < unlockTimestamp) {
            return 0;
        }
        return token.balanceOf(address(this));
    }

    function claim() public {
        require(
            msg.sender == getDetectiveAddress(),
            "should be bounty detective address"
        );
        require(block.timestamp >= getUnlockTimestamp(), "should wait");
        require(0 < getClaimableToken(), "insufficient amount");

        uint256 amount = getClaimableToken();

        token.safeTransfer(msg.sender, amount);

        emit Claim(msg.sender, amount);
    }

    receive() external payable {
        revert();
    }
}
