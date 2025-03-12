// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

abstract contract TwoPhaseOwnable is Context {
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "TwoPhaseOwnable: caller is not the owner");
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "TwoPhaseOwnable: new owner is the zero address");
        _pendingOwner = newOwner;
    }

    function acceptOwnership() public virtual {
        require(_msgSender() == pendingOwner(), "TwoPhaseOwnable: sender is not the next choosen one!");
        _setOwner(_pendingOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract GunfunnyToken is ERC20, ERC20Burnable, Pausable, TwoPhaseOwnable {

    uint256 public startTime;
    uint256 public endTime;
    uint256 public maxAmount;
    address public LPAddress;
    mapping (address => bool) listingBlacklisted;
    mapping (address => uint256) lastBuy;

    constructor() ERC20("Gunfunny Token", "GFY") {
        _mint(msg.sender, 5000000000 * (10 ** uint256(decimals())));  
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function checkListingBlacklisted(address _user) view external returns(bool) {
        return listingBlacklisted[_user];
    }

    function setupListing(address _LPAddress, uint256 _maxAmount, uint256 _startTime, uint256 _endTime) external onlyOwner {
		LPAddress = _LPAddress;
		maxAmount = _maxAmount;
		startTime = _startTime;
		endTime = _endTime;
	}

    function blackListListing(address _evil, bool _black) external onlyOwner {
        listingBlacklisted[_evil] = _black;
    }

    function batchBlackListListing(address[] memory _evil, bool[] memory _black) external onlyOwner {
        for (uint256 i = 0; i < _evil.length; i++) {
            listingBlacklisted[_evil[i]] = _black[i];
        }
    }

	function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
		if (msg.sender == LPAddress) {
            require(block.timestamp >= startTime, "GFY: Not yet open for trading");
            require(!listingBlacklisted[recipient], "GFY: This recipient was blacklisted!");
            if (block.timestamp < endTime) {
			    require(amount <= maxAmount, 'GFY: maxAmount exceed listing!');
                require(lastBuy[recipient] != block.number, "GFY: You already purchased in this block!");
                lastBuy[recipient] = block.number;
            }
		}
		_transfer(_msgSender(), recipient, amount);
		return true;
	}

}