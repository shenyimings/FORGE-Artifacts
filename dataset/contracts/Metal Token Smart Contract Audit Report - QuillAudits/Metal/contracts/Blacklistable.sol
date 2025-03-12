pragma solidity ^0.8;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Allows accounts to be blacklisted by an owner
*/
contract Blacklistable is Ownable {
    mapping (address => bool) internal blacklisted;

    event Blacklisted(address indexed _account);
    event RemovedBlackList(address indexed _account);

    /**
     * @dev Throws if argument account is blacklisted
     * @param _account The address to check
    */
    modifier notBlacklisted(address _account) {
        require(!isBlacklisted(_account));
        _;
    }

    /**
     * @dev Checks if account is blacklisted
     * @param _account The address to check    
    */
    function isBlacklisted(address _account) public view returns (bool) {
        return blacklisted[_account];
    }

    /**
     * @dev Adds account to blacklist
     * @param _account The address to blacklist
    */
    function blacklist(address _account) public onlyOwner {
        blacklisted[_account] = true;
        emit Blacklisted(_account);
    }

    /**
     * @dev Removes account from blacklist
     * @param _account The address to remove from the blacklist
    */
    function removeBlacklist(address _account) public onlyOwner {
        delete(blacklisted[_account]);
        emit RemovedBlackList(_account);
    }
}