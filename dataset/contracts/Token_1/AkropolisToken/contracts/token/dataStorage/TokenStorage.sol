pragma solidity ^0.4.24;

import "./AllowanceSheet.sol";
import "./BalanceSheet.sol";

/**
* @title TokenStorage
*/
contract TokenStorage {
    /**
        Storage
    */
    BalanceSheet public balances;
    AllowanceSheet public allowances;

    /**
    * @dev a TokenStorage consumer can set its storages only once, on construction
    *
    **/
    constructor (address _balances, address _allowances) public {
        balances = BalanceSheet(_balances);
        allowances = AllowanceSheet(_allowances);
    }

    /**
    * @dev claim ownership of balance sheet passed into constructor.
    **/
    function claimBalanceOwnership() public {
        balances.claimOwnership();
    }

    /**
    * @dev claim ownership of allowance sheet passed into constructor.
    **/
    function claimAllowanceOwnership() public {
        allowances.claimOwnership();
    }
}