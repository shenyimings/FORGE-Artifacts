// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MetaStrikeMTT is ERC20, ERC20Burnable, Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

	uint256 public startTime;
	uint256 public endTime;
	uint256 public maxAmount;
	address public LPAddress;
    mapping (address => bool) blacklisted;
    mapping (address => uint256) lastBuy;
    

    constructor() ERC20("Metastrike", "MTT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function checkBlacklisted(address _user) view external returns(bool) {
        return blacklisted[_user];
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

	function setupListing(address _LPAddress, uint256 _maxAmount, uint256 _startTime, uint256 _endTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
		LPAddress = _LPAddress;
		maxAmount = _maxAmount;
		startTime = _startTime;
		endTime = _endTime;
	}

    function blackList(address _evil, bool _black) external onlyRole(DEFAULT_ADMIN_ROLE) {
        blacklisted[_evil] = _black;
    }

    function batchBlackList(address[] calldata _evil, bool[] calldata _black) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < _evil.length; i++) {
            blacklisted[_evil[i]] = _black[i];
        }
    }

	
	/**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     */
	function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
		if (msg.sender == LPAddress) {
            require(block.timestamp >= startTime, "MTT: Not yet open for trading");
            if (block.timestamp < endTime) {
			    require(amount <= maxAmount, 'MTT: maxAmount exceed listing!');
                require(lastBuy[recipient] != block.number, "MTT: You already purchased in this block!");
                lastBuy[recipient] = block.number;
            }
		}

		_transfer(_msgSender(), recipient, amount);
		return true;
	}

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        require(!blacklisted[from], "MTT: This sender was blacklisted!");
        require(!blacklisted[to], "MTT: This recipient was blacklisted!");
        super._beforeTokenTransfer(from, to, amount);
    }
}
