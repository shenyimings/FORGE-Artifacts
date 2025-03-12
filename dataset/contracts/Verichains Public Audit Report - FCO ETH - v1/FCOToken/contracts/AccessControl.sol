// SPDX-License-Identifier: none
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

abstract contract AccessControl is Initializable {  
    using SafeERC20Upgradeable for IERC20Upgradeable;  
    IAuthority public authority;

    function __AccessControl_init(address authority_) internal onlyInitializing {
        __AccessControl_init_unchained(authority_);
    }

    function __AccessControl_init_unchained(address authority_) internal onlyInitializing {
        authority = IAuthority(authority_);       
    }
      
    function setAuthority(IAuthority _newAuthority) external onlyAdmin {
        authority = _newAuthority;        
    }

    function recover(
		address token_,
		uint256 amount_,
		address recipient_
	) external onlyAdmin {
        if (token_ != address(0)) {
			IERC20Upgradeable(token_).safeTransfer(recipient_, amount_);
		} else {
			(bool success, ) = recipient_.call{ value: amount_ }("");
			require(success, "Can't send ETH");
		}
	}

    modifier onlyAdmin() {
        require(msg.sender == authority.admin(), "Admin!");
        _;
    }

    modifier onlyOperator() {
        require(authority.operators(msg.sender), "Operator!");
        _;
    }
}

interface IAuthority {
    function admin() external view returns (address);
    function operators(address operator) external view returns (bool);
    function chainId() external view returns (uint256);
}

contract Authority is Initializable, IAuthority, AccessControl {
	address public override admin;
    mapping(address => bool) public override operators; 
    uint256 public chainId;
    
    function initialize(uint256 chainId_) public initializer {
        __AccessControl_init(address(this));       
        admin = tx.origin;
        chainId = chainId_; 
        //operators[tx.origin] = true; 
    }
	
	function setAdmin(address account) public onlyAdmin {		
		admin = account;        
	}	

    function setOperator(address account, bool state) public onlyAdmin {		
		operators[account] = state;         
	}

    uint256[50] private __gap;
}
