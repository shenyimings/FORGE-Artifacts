//Be name khoda

pragma solidity >=0.6.0 <0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

import "FeeCalculator.sol";

contract TransferController{

	constructor() public{}
	
	function afterTokenTransfer(address from, address to, uint256 value) public{}
}

contract SealedToken is ERC20, AccessControl{

    using SafeMath for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
	bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

	TransferController public transferController;
	FeeCalculator public feeCalculator;
	address public feeCollector;

    constructor(
		string memory name,
		string memory symbol,
		address _feeCalculator,
		address _feeCollector,
		address simpleTransferController,
		address admin) 
		public ERC20(name, symbol) {
			_setupRole(DEFAULT_ADMIN_ROLE, admin);
			_setupRole(CONFIG_ROLE, admin);
			_setupRole(MINTER_ROLE, msg.sender);
			_setupRole(BURNER_ROLE, msg.sender);

			transferController = TransferController(simpleTransferController);
			feeCalculator = FeeCalculator(_feeCalculator);
			feeCollector = _feeCollector;
    }

	function setFeeCollector(address _feeCollector) public{
		require(hasRole(CONFIG_ROLE, msg.sender), "Caller is not a configer");
		feeCollector = _feeCollector;
	}

	function setFeeCalculator(address _feeCalculator) public{
		require(hasRole(CONFIG_ROLE, msg.sender), "Caller is not a configer");
		feeCalculator = FeeCalculator(_feeCalculator);
	}

	function setTransferController(address _transferController) public{
		require(hasRole(CONFIG_ROLE, msg.sender), "Caller is not a configer");
		transferController = TransferController(_transferController);
	}

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        require(hasRole(BURNER_ROLE, msg.sender), "Caller is not a burner");
        _burn(from, amount);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
		uint256 feeAmount = feeCalculator.calculateFee(address(this), recipient, msg.sender, amount);
		uint256 receivedAmount = amount.sub(feeAmount);
		if (feeAmount > 0){
			super.transfer(feeCollector, feeAmount);
		}
		super.transfer(recipient, receivedAmount);
		transferController.afterTokenTransfer(msg.sender, recipient, receivedAmount);
        return true;
    }

	function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
		uint256 feeAmount = feeCalculator.calculateTransferFromFee(address(this), sender, recipient, amount, msg.sender);
		uint256 receivedAmount = amount.sub(feeAmount);
		if (feeAmount > 0){
			_transfer(sender, feeCollector, feeAmount);
		}
        _transfer(sender, recipient, receivedAmount);
        _approve(sender, _msgSender(), allowance(sender, _msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance"));
		transferController.afterTokenTransfer(sender, recipient, receivedAmount);
        return true;
    }

}

//Dar panah khoda
