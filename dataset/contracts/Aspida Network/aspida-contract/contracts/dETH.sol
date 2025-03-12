// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";

import "./library/PauseGuardian.sol";
import "./library/Manable.sol";
import "./library/Minter.sol";

/**
 * @title Aspida's ether pegged ERC20 token
 * @notice This contract is used to create an ether pegged ERC20 token
 * @dev This contract extends multiple OpenZeppelin contracts to add additional functionality.
 * @author Aspida engineer
 */
contract dETH is
    Ownable2StepUpgradeable,
    PauseGuardian,
    ERC20BurnableUpgradeable,
    ERC20PermitUpgradeable,
    Manable,
    Minter
{
    /**
     * @notice Only for the implementation contract, as for the proxy pattern,
     *            should call `initialize()` separately.
     */
    constructor() {
        initialize();
    }

    /**
     * @notice Initializes the dETH contract.
     * @dev This function should be called only once to initialize dETH.
     */
    function initialize() public initializer {
        string memory _tokenName = "Aspida Ether";
        string memory _tokenSymbol = "dETH";
        __Ownable2Step_init();
        __ERC20_init(_tokenName, _tokenSymbol);
        __ERC20Permit_init(_tokenName);
    }

    /**
     * @dev Unpauses the dETH contract.
     * @notice This function can only be called by the contract owner.
     */
    function _open() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Pauses the dETH contract.
     * @notice This function can only be called by the pause guardian.
     */
    function _close() external onlyPauseGuardian {
        _pause();
    }

    /**
     * @dev Adds a new pause guardian.
     * @param _pauseGuardian The address of the pause guardian to be added.
     * @notice This function can only be called by the contract owner.
     */
    function _addPauseGuardian(address _pauseGuardian) external onlyOwner {
        _addPauseGuardianInternal(_pauseGuardian);
    }

    /**
     * @dev Removes a pause guardian.
     * @param _pauseGuardian The address of the pause guardian to be removed.
     * @notice This function can only be called by the contract owner.
     */
    function _removePauseGuardian(address _pauseGuardian) external onlyOwner {
        _removePauseGuardianInternal(_pauseGuardian);
    }

    /**
     * @notice Adds a new manager.
     * @param _manager The address of the manager to be added.
     * @dev If the manager has not been added before, emits a `ManagerAdded` event.
     * @notice This function can only be called by the contract owner.
     */
    function _addManager(address _manager) external onlyOwner {
        _addManagerInternal(_manager);
    }

    /**
     * @notice Removes a manager.
     * @param _manager The address of the manager to be removed.
     * @dev If the manager is currently a manager, emits a `ManagerRemoved` event.
     * @notice This function can only be called by the contract owner.
     */
    function _removeManager(address _manager) external onlyOwner {
        _removeManagerInternal(_manager);
    }

    /**
     * @notice Sets the minting cap for a minter.
     * @param _minter The address of the minter.
     * @param _mintCap The new minting cap for the minter.
     * @notice This function can only be called by the contract owner.
     */
    function _setMinterCap(address _minter, uint256 _mintCap) external onlyOwner {
        _setMinterCapInternal(_minter, _mintCap);
    }

    /**
     * @dev Hook function called before any token transfer.
     * @param from The address transferring the tokens.
     * @param to The address receiving the tokens.
     * @param amount The amount of tokens being transferred.
     * @notice This function checks if the token is paused before allowing the transfer.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        require(!paused(), "_beforeTokenTransfer: token transfer while paused");
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @notice Mints new tokens and assigns them to the specified receiver.
     * @param _receiver The address to receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     * @notice This function can only be called by a manager.
     */
    function mint(address _receiver, uint256 _amount) external onlyManager {
        _mint(_receiver, _amount);
    }

    /**
     * @notice Mints new tokens and assigns them to the specified receiver.
     * @param _receiver The address to receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     * @dev This function checks if the minting cap is not exceeded before minting.
     */
    function minterMint(address _receiver, uint256 _amount) external checkMintCap(_amount) {
        _increaseMintAmount(msg.sender, _amount);
        _mint(_receiver, _amount);
    }

    /**
     * @notice Burns tokens from the sender's balance.
     * @param _amount The amount of tokens to burn.
     * @dev This function decreases the minting amount for the sender before burning.
     */
    function minterBurn(uint256 _amount) external {
        _decreaseMintAmount(msg.sender, _amount);
        _burn(msg.sender, _amount);
    }

    /**
     * @notice Burns tokens from a specified account.
     * @param _account The account to burn tokens from.
     * @param _amount The amount of tokens to burn.
     * @dev This function allows burning tokens from another account if the sender has the necessary allowance.
     */
    function burnFrom(address _account, uint256 _amount) public override {
        address _sender = msg.sender;
        if (_sender != _account) _spendAllowance(_account, _sender, _amount);
        _burn(_account, _amount);
    }

    /**
     * @notice Checks if an address is a pause guardian.
     * @param _pauseGuardian The address to check.
     * @return A boolean indicating whether the address is a pause guardian.
     */
    function isPauseGuardian(address _pauseGuardian) public view override returns (bool) {
        return PauseGuardian.isPauseGuardian(_pauseGuardian) || _pauseGuardian == owner();
    }
}
