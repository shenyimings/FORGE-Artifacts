// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import "./library/PauseGuardian.sol";
import "./strategy/model/dETHMinter.sol";

import "./interface/IdETH.sol";
import "./interface/ILido.sol";

/**
 * @title StETHMinter contract for Aspida's Lido
 * @author Aspida engineer
 */
contract StETHMinter is Ownable2StepUpgradeable, PauseGuardian, dETHMinter {
    using TransferHelper for address;
    address internal immutable STETH;

    constructor(IdETH _dETH, address _stETH) dETHMinter(_dETH) {
        STETH = _stETH;
        initialize();
    }

    /**
     * @notice Initializes StETHMinter contract
     * @dev Expects to call only once to initialize StETHMinter.
     */
    function initialize() public initializer {
        __Ownable2Step_init();
        _setReceiverInternal(address(this));
    }

    /**
     * @notice Unpauses StETHMinter contract
     * @dev Unpause when StETHMinter is paused.
     */
    function _open() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Pauses StETHMinter contract
     * @dev Pause StETHMinter.
     */
    function _close() external onlyPauseGuardian {
        _pause();
    }

    /**
     * @notice Adds pause guardian
     * @param _pauseGuardian Address of pause guardian to be added
     */
    function _addPauseGuardian(address _pauseGuardian) external onlyOwner {
        _addPauseGuardianInternal(_pauseGuardian);
    }

    /**
     * @notice Removes pause guardian
     * @param _pauseGuardian Address of pause guardian to be removed
     */
    function _removePauseGuardian(address _pauseGuardian) external onlyOwner {
        _removePauseGuardianInternal(_pauseGuardian);
    }

    /**
     * @notice Sets receiver address
     * @param _receiver Address of receiver to be set
     */
    function _setReceiver(address _receiver) external onlyOwner {
        _setReceiverInternal(_receiver);
    }

    /**
     * @notice Transfers tokens to specified address
     * @param _token Address of token to be transferred
     * @param _amount Amount of tokens to be transferred
     * @param _to Address of receiver
     */
    function _transferOut(address _token, uint256 _amount, address _to) external onlyOwner {
        _token.safeTransfer(_to, _amount);
    }

    /**
     * @notice Deposits StETH tokens
     * @param _sender Address of sender
     * @param _receiver Address of receiver
     * @param _stETHAmount Amount of StETH tokens to be deposited
     */
    function _deposit(address _sender, address _receiver, uint256 _stETHAmount) internal override whenNotPaused {
        super._deposit(_sender, _receiver, _stETHAmount);
    }

    /**
     * @notice Converts StETH tokens to dETH tokens
     * @param _stETHAmount Amount of StETH tokens to be converted
     * @return uint256 Amount of dETH tokens
     */
    function _convertToDETH(uint256 _stETHAmount) internal pure override returns (uint256) {
        return _stETHAmount;
    }

    /**
     * @notice Returns address of StETH token
     * @return address Address of StETH token
     */
    function _depositAsset() internal view override returns (address) {
        return STETH;
    }

    /**
     * @notice Deposits StETH tokens with permit
     * @param _stETHAmount Amount of StETH tokens to be deposited
     * @param _receiver Address of receiver
     * @param _deadline Deadline for permit
     * @param _approveMax Boolean indicating whether to approve max amount
     * @param _v ECDSA signature parameter
     * @param _r ECDSA signature parameter
     * @param _s ECDSA signature parameter
     */
    function depositWithPermit(
        uint256 _stETHAmount,
        address _receiver,
        uint256 _deadline,
        bool _approveMax,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        uint256 _amount = _approveMax ? type(uint256).max : _stETHAmount;
        IStETH(STETH).permit(msg.sender, address(this), _amount, _deadline, _v, _r, _s);
        _deposit(msg.sender, _receiver, _stETHAmount);
    }

    /**
     * @notice Checks if address is pause guardian
     * @param _pauseGuardian Address to be checked
     * @return bool Boolean indicating whether address is pause guardian
     */
    function isPauseGuardian(address _pauseGuardian) public view override returns (bool) {
        return PauseGuardian.isPauseGuardian(_pauseGuardian) || _pauseGuardian == owner();
    }

    /**
     * @notice Returns deposit cap
     * @return uint256 Deposit cap
     */
    function depositCap() external view returns (uint256) {
        return DETH.mintCap(address(this));
    }

    /**
     * @notice Returns deposit amount
     * @return uint256 Deposit amount
     */
    function depositAmount() external view returns (uint256) {
        return DETH.mintAmount(address(this));
    }
}
