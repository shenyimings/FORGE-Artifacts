/*  _____________________________________________________________________________

    Gauss(Gang) Token Contract

    Name             : Gauss
    Symbol           : GANG
    Total supply     : 250,000,000 (250 Million)

    MIT License. (c) 2021 Gauss Gang Inc. 
    
    _____________________________________________________________________________
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
import "../dependencies/utilities/Initializable.sol";
import "../dependencies/utilities/UUPSUpgradeable.sol";
import "../dependencies/contracts/BEP20.sol";
import "../dependencies/contracts/BEP20Snapshot.sol";
import "../dependencies/contracts/AddressBook.sol";



/*  A tokenized ecosystem to serve the evolving needs of any brand. 
    The purpose of the Gauss ecosystem is to support and work with brands to launch utility tokens on 
    our future blockchain and empower them to engage with their audiences in a new, captivating manner.
*/
contract GaussGANG is Initializable, BEP20, BEP20Snapshot, AddressBook, UUPSUpgradeable {

    // Initializes variables representing the seperate fees that comprise the Transaction Fee.
    uint256 public redistributionFee;
    uint256 public charitableFundFee;
    uint256 public liquidityFee;
    uint256 public ggFee;
    uint256 private _totalFee;


    // Calls te BEP20 Initializer and internal Initializer to create the Gauss GANG token and set required variables.
    function initialize() initializer public {
        __BEP20_init("Gauss", "GANG", 9, (250000000 * (10 ** 9)));
        __BEP20Snapshot_init_unchained();
        __UUPSUpgradeable_init();
        __AddressManager_init();
        __GaussGANG_init_unchained();
    }


    // Sets initial values to the Transaction Fees and wallets to be excluded from the Transaction Fee.
    function __GaussGANG_init_unchained() internal initializer {

        // Sets values for the variables, representing the seperate fees, that comprise the Total Transaction Fee.
        redistributionFee = 3;
        charitableFundFee = 3;
        liquidityFee = 3;
        ggFee = 3;
        _totalFee = 12;
    }


    // Creates a Snapshot of the balances and totalsupply of token, returns the Snapshot ID. Can only be called by owner.
    function snapshot() public onlyOwner returns (uint256) {
        uint256 id = _snapshot();
        return id;
    }


    // Returns the current total Transaction Fee.
    function totalTransactionFee() public view returns (uint256) {
        return _totalFee;
    }


    /*  Allows 'owner' to change the transaction fees at a later time, so long as the total Transaction Fee is lower than 12% (the initial fee ceiling).
            -An amount for each Pool is required to be entered, even if the specific fee amount won't be changed.
            -Each variable should be entered as a single or double digit number to represent the intended percentage; 
                Example: Entering a 3 for newRedistributionFee would set the Redistribution fee to 3% of the Transaction Amount.
    */
    function changeTransactionFees(uint256 newRedistributionFee, uint256 newCharitableFundFee, uint256 newLiquidityFee, uint256 newGGFee) external onlyOwner() {

        uint256 newTotalFee;
        newTotalFee = (newRedistributionFee + newCharitableFundFee + newLiquidityFee + newGGFee);

        require(newTotalFee <= 12, "GaussGANG: Transaction fee entered exceeds ceiling of 12%");

        redistributionFee = newRedistributionFee;
        charitableFundFee = newCharitableFundFee;
        liquidityFee = newLiquidityFee;
        ggFee = newGGFee;
        _totalFee = newTotalFee;
    }


    // Internal Transfer function; checks to see if "sender" is excluded from the transaction fee, attempts the transaction without fees if found true.
    function _transfer(address sender, address recipient, uint256 amount) internal whenNotPaused override(BEP20) {

        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        if (_checkIfExcluded(sender, recipient) == 1) {            
            require(amount <= _balances[sender], "BEP20: transfer amount exceeds balance");

            unchecked {
                _balances[sender] = _balances[sender] - amount;
            }

            _balances[recipient] += amount;
            emit Transfer(sender, recipient, amount);
        }

        else {
            _transferWithFee(sender, recipient, amount);
        }
    }


    /*  Internal Transfer function; takes out transaction fees before sending remaining to 'recipient'.
            -At launch, the transaction fee is set to 12%, but will be lowered over time.
            -The max transaction fee is also 12%, never raising beyond the initial fee set at launch.
            -Fee is evenly split between 4 Pools: 
                    The Redistribution pool,        (Initially, 3%)
                    the Charitable Fund pool,       (Initially, 3%)
                    the Liquidity pool,             (Initially, 3%)
                    and Gauss Gang pool             (Initially, 3%)
    */
    function _transferWithFee(address sender, address recipient, uint256 amount) internal {

        // This section calculates the number of tokens, for the pools that comprise the transaction fee, that get pulled out of "amount" for the transaction fee.
        uint256 redistributionAmount = (amount * redistributionFee) / 100;
        uint256 charitableFundAmount = (amount * charitableFundFee) / 100;
        uint256 liquidityAmount = (amount * liquidityFee) / 100;
        uint256 ggAmount = (amount * ggFee) / 100;
        uint256 finalAmount = amount - (redistributionAmount + charitableFundAmount + liquidityAmount + ggAmount);

        /*  This section performs the balance transfer from "sender" to "recipient".
                - First ensuring the original "amount" is removed from the "sender" and the "finalAmount" ("amount" - transaction fee)
                    is sent to the "recipient".
                - After those transactions are complete, the transaction fee is divided up and sent to the respective pool addresses.
        */
        require(amount <= _balances[sender], "BEP20: transfer amount exceeds balance");
        require(finalAmount <= amount, "GaussGANG: finalAmount exceeds original amount");

        unchecked {
            _balances[sender] = _balances[sender] - amount;
        }

        _balances[recipient] += finalAmount;
        _balances[gaussWallets["Redistribution Fee Wallet"]] += redistributionAmount;
        _balances[gaussWallets["Charitable Fee Wallet"]] += charitableFundAmount;
        _balances[gaussWallets["Liquidity Fee Wallet"]] += liquidityAmount;
        _balances[gaussWallets["GG Fee Wallet"]] += ggAmount;

        emit Transfer(sender, recipient, finalAmount);
        emit Transfer(sender, gaussWallets["Redistribution Fee Wallet"], redistributionAmount);
        emit Transfer(sender, gaussWallets["Charitable Fee Wallet"], charitableFundAmount);
        emit Transfer(sender, gaussWallets["Liquidity Fee Wallet"], liquidityAmount);
        emit Transfer(sender, gaussWallets["GG Fee Wallet"], ggAmount);
    }


    // Internal function to check if sender or recipient are excluded from the Transaction Fee.
    //      Dev-Note: Boolean cost more gas than uint256; using 0 to represent false, and 1 to represent true.
    function _checkIfExcluded(address sender, address recipient) internal view returns (uint256) {
        if (excludedFromFee[sender] == true) {
            return 1;
        }

        else if (excludedFromFee[recipient] == true) {
            return 1;
        }

        else {
            return 0;
        }
    }


    // Internal function; overriden to allow BEPSnapshot to update values before a Transfer event.
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(BEP20, BEP20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);
    }


    // Function to allow "owner" to upgarde the contract using a UUPS Proxy.
    function _authorizeUpgrade(address newImplementation) internal whenPaused onlyOwner override {}
}