// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interface/IERC20.sol";
import "../common/Ownable.sol";

contract Battle is Ownable {
    using SafeMath for uint256;

    // Vemp token address
    address public vemp;

    // xsVemp contract address
    address public xsVemp;

    // represent current staked Vemp amount
    uint256 public stakedVempAmount;

    function initialize(address owner_, address _xsVemp, address _vemp) public initializer {
        require(_xsVemp != address(0), "Invalid _xsVemp address");
        require(_vemp != address(0), "Invalid _vemp address");
        require(owner_ != address(0), "Invalid owner_ address");

        Ownable.init(owner_);
        xsVemp = _xsVemp;
        vemp = _vemp;
    }

    /**
     * @dev Used to enter the battle. pay some VEMP to get battle tokens.
     *
     * @param _user address of xsVemp tokens receiver
     * @param _amount amount of vemp lock by user
     */
    function enter(address _user, uint256 _amount) public {
        require(IERC20(vemp).balanceOf(msg.sender) >= _amount, "Insufficient VEMP Balance");
        IERC20(vemp).transferFrom(msg.sender, address(this), _amount);
        stakedVempAmount = stakedVempAmount.add(_amount);
        IERC20(xsVemp).mint(_user, _amount);
    }

    /**
     * @dev Used for leave the Battle to claim back your VEMP.
     *
     * @param _user address of vemp tokens receiver
     * @param _amount amount of vemp receive by user
     */
    function leave(address _user, uint256 _amount) public {
        require(IERC20(xsVemp).balanceOf(msg.sender) >= _amount, "Insufficient xsVemp Balance");
        IERC20(xsVemp).burnFrom(address(msg.sender), _amount);
        stakedVempAmount = stakedVempAmount.sub(_amount);
        IERC20(vemp).transfer(_user, _amount);
    }

    /**
     * @dev Used only by admin or owner, used to withdraw locked vemp tokens in emergency
     *
     * @param _token address of erc20 token contract
     * @param _to address of vemp tokens receiver
     * @param _amount amount of vemp and must be less than total locked amount
     */
    function emergencyWithdrawVempTokens(address _token, address _to, uint256 _amount)
        public
        onlyOwner
    {
        require(_to != address(0), "Invalid _to address");
        require(_token != address(0), "Invalid _to address");
        uint256 vempBal = IERC20(_token).balanceOf(address(this));
        require(vempBal >= _amount, "Insufficiently amount");
        IERC20(_token).transfer(_to, _amount);
    }
}