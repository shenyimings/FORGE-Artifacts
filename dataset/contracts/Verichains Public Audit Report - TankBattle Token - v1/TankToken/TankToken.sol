// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "./ERC20.sol";
import "./Pausable.sol";
import "./AccessControl.sol";

import "./GasPriceController.sol";
import "./DexListing.sol";
import "./TransferFee.sol";

contract TankToken is ERC20, GasPriceController, DexListing, TransferFee, Pausable, AccessControl {

    bytes32 private constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 private constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    mapping(address => bool) private blackListedList;
    uint256 private initialTokensSupply = 1000000000 * 10 ** decimals(); //1B
    constructor()
    ERC20("TankBattle Token", "TBL")
    DexListing(100)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _mint(msg.sender, initialTokensSupply);
        _setTransferFee(msg.sender, 0, 0, 0);
    }

    /*
       Override
   */

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        require(
            !blackListedList[from] && !blackListedList[to],
            "Address is blacklisted"
        );
        super._beforeTokenTransfer(from, to, amount);
    }

    function _transfer(
        address sender_,
        address recipient_,
        uint256 amount_
    )
    internal
    override
    onlyValidGasPrice
    {
        if (!_listingFinished) {
            uint fee = _updateAndGetListingFee(sender_, recipient_, amount_);
            require(fee <= amount_, "Token: listing fee too high");
            uint transferA = amount_ - fee;
            if (fee > 0) {
                super._transfer(sender_, _getTransferFeeTo(), fee);
            }
            super._transfer(sender_, recipient_, transferA);
        } else {
            uint transferFee = _getTransferFee(sender_, recipient_, amount_);
            require(transferFee <= amount_, "Token: transferFee too high");
            uint transferA = amount_ - transferFee;
            if (transferFee > 0) {
                super._transfer(sender_, _getTransferFeeTo(), transferFee);
            }
            if (transferA > 0) {
                super._transfer(sender_, recipient_, transferA);
            }
        }
    }

    /*
        Settings
    */

    function setMaxGasPrice(
        uint maxGasPrice_
    )
    external
    onlyRole(ADMIN_ROLE)
    {
        _setMaxGasPrice(maxGasPrice_);
    }

    function setTransferFee(
        address to_,
        uint buyFee_,
        uint sellFee_,
        uint normalFee_
    )
    external
    onlyRole(ADMIN_ROLE)
    {
        _setTransferFee(to_, buyFee_, sellFee_, normalFee_);
    }

    function addBlackList(address _address) external onlyRole(ADMIN_ROLE) {
        blackListedList[_address] = true;
    }

    function addBlackLists(address[] calldata _address) external onlyRole(ADMIN_ROLE) {
        uint256 count = _address.length;
        for (uint256 i = 0; i < count; i++) {
            blackListedList[_address[i]] = true;
        }
    }

    function removeBlackList(address _address) external onlyRole(ADMIN_ROLE) {
        blackListedList[_address] = false;
    }

    function removeBlackLists(address[] calldata _address) external onlyRole(ADMIN_ROLE) {
        uint256 count = _address.length;
        for (uint256 i = 0; i < count; i++) {
            blackListedList[_address[i]] = false;
        }
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual onlyRole(BURNER_ROLE) {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount)
    public
    virtual
    onlyRole(BURNER_ROLE)
    {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(
            currentAllowance >= amount,
            "ERC20: burn amount exceeds allowance"
        );
    unchecked {
        _approve(account, _msgSender(), currentAllowance - amount);
    }
        _burn(account, amount);
    }

    /*
         Withdraw
     */

    function withdrawBalance() public onlyRole(ADMIN_ROLE) {
        address payable _owner = payable(_msgSender());
        _owner.transfer(address(this).balance);
    }

    function withdrawTokens(address _tokenAddr, address _to)
    public
    onlyRole(ADMIN_ROLE)
    {
        require(
            _tokenAddr != address(this),
            "Cannot transfer out tokens from contract!"
        );
        require(isContract(_tokenAddr), "Need a contract address");
        ERC20(_tokenAddr).transfer(
            _to,
            ERC20(_tokenAddr).balanceOf(address(this))
        );
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}