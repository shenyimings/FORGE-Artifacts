//Be name khoda

pragma solidity >=0.6.0 <0.8.0;

interface WETH9 {
	function deposit() external payable;
	function approve(address guy, uint wad) external returns (bool);
}

interface Vault {
	function lockFor(uint256 amount, address _user) external returns (uint256);
	function sealedAndTimeAmount(address _user, uint256 amount) external view returns (uint256, uint256);
}

interface SealedToken {
	function transfer(address recipient, uint256 amount) external returns (bool);
}

contract WethProxy{
	Vault public ethVault;
	WETH9 public wethToken;
	SealedToken public sealedToken;

	constructor(address ethVaultAddress, address wethAddress, address _sealedToken) public{
		ethVault = Vault(ethVaultAddress);
		wethToken = WETH9(wethAddress);
		wethToken.approve(ethVaultAddress,1e50);
		sealedToken = SealedToken(_sealedToken);
	}

	function lock() public payable{
		wethToken.deposit{value:msg.value}();
		uint256 sealedAmount = ethVault.lockFor(msg.value, msg.sender);
		sealedToken.transfer(msg.sender, sealedAmount);
	}

	function sealedAndTimeAmount(address user, uint256 amount) public view returns (uint256, uint256) {
		return ethVault.sealedAndTimeAmount(user, amount);
	}
}

//Dar panah khoda