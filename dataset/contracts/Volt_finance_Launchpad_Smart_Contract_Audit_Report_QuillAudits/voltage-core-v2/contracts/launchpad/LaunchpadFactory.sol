// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Launchpad.sol";

contract LaunchpadFactory is Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant SCALE = 1000;

    /// @dev The voltage vote-escrow token.
    address public immutable veVolt;

    /// @dev The withdraw fee.
    uint256 public withdrawFee;

    /// @dev The launchpad fee.
    uint256 public launchpadFee;

    /// @dev Launchpad addresses by project token.
    mapping(address => address) public launchpads;

    event LaunchCreated(
        address indexed projectToken,
        address indexed saleToken,
        uint256 minSaleTokenReserve
    );

    event LaunchpadFeeChanged(uint256 oldFee, uint256 newFee);

    event WithdrawFeeChanged(uint256 oldFee, uint256 newFee);

    constructor(address _veVolt, uint256 _withdrawFee, uint256 _launchpadFee) {
        require(_withdrawFee > 0 && _withdrawFee < 50, "constructor: withdraw fee should be less than 5%");
        require(_launchpadFee > 0 && _launchpadFee < 50, "constructor: launchpad fee should be less than 5%");

        veVolt = _veVolt;
        withdrawFee = _withdrawFee;
        launchpadFee = _launchpadFee;
    }

    /// @dev Set the launchpad fee
    function setLaunchpadFee(uint256 _newFee) public onlyOwner {
        require(_newFee > 0 && _newFee < 50, "setLaunchpadFee: launchpad fee should be less than 5%");
        
        uint256 oldFee = launchpadFee;
        launchpadFee = _newFee;

        emit LaunchpadFeeChanged(oldFee, _newFee);
    }

    /// @dev Set the withdraw fee
    function setWithdrawFee(uint256 _newFee) public onlyOwner {
        require(_newFee > 0 && _newFee < 50, "setWithdrawFee: withdraw fee should be less than 5%");
        
        uint256 oldFee = withdrawFee;
        withdrawFee = _newFee;

        emit WithdrawFeeChanged(oldFee, _newFee);
    }

    /// @dev Create a new launchpad
    function createLaunchpad(LaunchpadParams memory _params) public onlyOwner {
        require(
            launchpads[_params.projectToken] == address(0),
            "createLaunchpad: token already launched"
        );

        address launch = address(new Launchpad(_params));

        IERC20(_params.projectToken).safeTransferFrom(
            msg.sender,
            launch,
            _params.projectTokenReserve
        );

        launchpads[_params.projectToken] = launch;
    }
}
