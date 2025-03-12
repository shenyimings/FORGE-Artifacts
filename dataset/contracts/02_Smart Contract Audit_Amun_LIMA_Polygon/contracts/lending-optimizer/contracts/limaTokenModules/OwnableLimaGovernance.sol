pragma solidity ^0.6.12;


// import "@openzeppelin/upgrades/contracts/Initializable.sol";
import { Initializable} from "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an limaGovernance) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the limaGovernance account will be the one that deploys the contract. This
 * can later be changed with {transferLimaGovernanceOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyLimaGovernance`, which can be applied to your functions to restrict their use to
 * the limaGovernance.
 */
contract OwnableLimaGovernance is Initializable {
    address private _limaGovernance;

    event LimaGovernanceOwnershipTransferred(address indexed previousLimaGovernance, address indexed newLimaGovernance);

    /**
     * @dev Initializes the contract setting the deployer as the initial limaGovernance.
     */

    function __OwnableLimaGovernance_init_unchained() internal initializer {
        address msgSender = msg.sender;
        _limaGovernance = msgSender;
        emit LimaGovernanceOwnershipTransferred(address(0), msgSender);

    }


    /**
     * @dev Returns the address of the current limaGovernance.
     */
    function limaGovernance() public view returns (address) {
        return _limaGovernance;
    }

    /**
     * @dev Throws if called by any account other than the limaGovernance.
     */
    modifier onlyLimaGovernance() {
        require(_limaGovernance == msg.sender, "OwnableLimaGovernance: caller is not the limaGovernance");
        _;
    }

    /**
     * @dev Transfers limaGovernanceship of the contract to a new account (`newLimaGovernance`).
     * Can only be called by the current limaGovernance.
     */
    function transferLimaGovernanceOwnership(address newLimaGovernance) public virtual onlyLimaGovernance {
        require(newLimaGovernance != address(0), "OwnableLimaGovernance: new limaGovernance is the zero address");
        emit LimaGovernanceOwnershipTransferred(_limaGovernance, newLimaGovernance);
        _limaGovernance = newLimaGovernance;
    }

}
