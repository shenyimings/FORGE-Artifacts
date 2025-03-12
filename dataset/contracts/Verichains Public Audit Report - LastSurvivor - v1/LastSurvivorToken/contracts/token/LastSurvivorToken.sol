pragma solidity ^0.8.0;
import "../dependencies/open-zeppelin/token/ERC20/ERC20.sol";
import "../dependencies/open-zeppelin/access/Ownable.sol";


interface IBPContract {

    function protect(address sender, address receiver, uint256 amount) external;

}

contract LastSurvivorToken is ERC20, Ownable{
    
    IBPContract public bpContract;

    bool public bpEnabled;
    bool public bpDisabledForever;

    constructor()
        ERC20("Last Survivor", "LSC")
    {
        _mint(msg.sender, 1_200_000_000 * 10**18);
    }


    function setBPContract(address addr)
        public
        onlyOwner
    {
        require(addr != address(0), "BP adress cannot be 0x0");

        bpContract = IBPContract(addr);
    }

    function setBPEnabled(bool enabled)
        public
        onlyOwner
    {
        bpEnabled = enabled;
    }

    function setBPDisableForever()
        public
        onlyOwner
    {
        require(!bpDisabledForever, "Bot protection disabled");

        bpDisabledForever = true;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        if (bpEnabled && !bpDisabledForever) {
            bpContract.protect(from, to, amount);
        }

        super._beforeTokenTransfer(from, to, amount);

    }

   /**
     * Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /* ========== EMERGENCY ========== */
    function emergencySupport(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }
}