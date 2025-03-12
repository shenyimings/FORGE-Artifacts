// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";

abstract contract BPContract {
    function protect(
        address sender,
        address receiver,
        uint256 amount
    ) external virtual;
}

contract ASTARToken is AccessControl, ERC20, ERC20Snapshot, ERC20Pausable {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant OPERATION_ROLE = keccak256("OPERATION_ROLE");

    bool public isInPreventBotMode;

    BPContract public BP;

    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    IUniswapV2Router02 constant public uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    uint public MAX_SUPPLY = 1000000000 * (10 ** decimals());
    address public pairASTARBUSD;
    uint public amountIn;
    uint public amountOut;
    uint public percentMint;

    address public foundation;
    address public advisors;
    address public teams;
    address public stakeFarming;
    address public ecosystem;
    address public marketing;
    address public liquidity;

    event ReserveMinted(uint amount, uint block);
    event SetPercentMint(uint percent);

    constructor() ERC20("AceStarter", "ASTAR") {
        IUniswapV2Factory uniswapV2Factory = IUniswapV2Factory(uniswapV2Router.factory());
        pairASTARBUSD = uniswapV2Factory.createPair(address(this), BUSD);

        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _setRoleAdmin(OPERATION_ROLE, OWNER_ROLE);
        _setupRole(OWNER_ROLE, msg.sender);

        foundation = 0x46CD1D3b37EFCfDbaA09E33f28D567d5292c36Fb;
        advisors = 0xb640bE83412903EAA0785480D109f784a3d898bE;
        teams = 0xF11E72aaDa64756C17A3903E6eB1E53aC1f9237a;
        stakeFarming = 0x60F8Fc3198A604151045B8e42D885A65deE7550B;
        ecosystem = 0x1ecd22E259a9C6e691b0Ac8689A589d519baBda6;
        marketing = 0xaE7f3B41839D40F4149489A3c77d126493986Ad6;
        liquidity = 0x6B721eBDbAcf0B9340Ad54aB5A8A442A21D65E1A;

        // Seed Round
        _mint(0x3E1B442Ef98bCB5afaF68C37D78aA78747442BAA, 50000000 * (10 ** decimals()));
        // IDO
        _mint(0x33f3c03542d73aFdEFDad9B76d9b81F4e563aee0, 50000000 * (10 ** decimals()));
        // Liquidity
        _mint(liquidity, 20000000 * (10 ** decimals()));
    }
    /**
     * Operation functions
     */
    function mint() external onlyRole(OPERATION_ROLE) {
        require(percentMint > 0, "ASTAR:: must be config percent mint");
        if (amountOut > amountIn) {
            uint amount = (amountOut - amountIn) * percentMint / 1000000;
            if (totalSupply() + amount > MAX_SUPPLY)
            {
                amount -= totalSupply() + amount - MAX_SUPPLY;
            }
            require(amount > 0, "ASTAR:: max minted");
            _mint(foundation, amount * 100000 / 1000000);
            _mint(advisors, amount * 100000 / 1000000);
            _mint(teams, amount * 150000 / 1000000);
            _mint(stakeFarming, amount * 310000 / 1000000);
            _mint(ecosystem, amount * 90000 / 1000000);
            _mint(marketing, amount * 100000 / 1000000);
            _mint(liquidity, amount * 150000 / 1000000);
            emit ReserveMinted(amount, block.number);
        }
        amountIn = 0;
        amountOut = 0;
    }

    function setPercentMint(uint percent) external onlyRole(OPERATION_ROLE) {
        require(percent < 1000000, "ASTAR:: invalid percent");
        percentMint = percent;
        emit SetPercentMint(percent);
    }
    /**
     * Utilities functions
     */
    function snapshot() public onlyRole(OWNER_ROLE) returns (uint) {
        return _snapshot();
    }

    function pause() public onlyRole(OWNER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(OWNER_ROLE) {
        _unpause();
    }

    function togglePreventBotMode() public onlyRole(OWNER_ROLE) {
        isInPreventBotMode = !isInPreventBotMode;
    }

    function setBPContract(address _bp) public onlyRole(OWNER_ROLE) {
        require(address(BP) == address(0), "ASTAR:: unauthorazion");
        BP = BPContract(_bp);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal whenNotPaused override(ERC20, ERC20Pausable, ERC20Snapshot) {
        if (isInPreventBotMode) {
            BP.protect(from, to, amount);
        }
        if (from == pairASTARBUSD) {
            amountOut += amount;
        }
        if (to == pairASTARBUSD) {
            amountIn += amount;
        }
        super._beforeTokenTransfer(from, to, amount);
    }

    function burn(uint256 amount) public {
        MAX_SUPPLY -= amount;
        _burn(msg.sender, amount);
    }
}