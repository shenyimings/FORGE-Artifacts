// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "./Owned.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IToken {
    function mint(address recipient, uint256 amount) external;

    function burn(uint256 amount) external;

    function burnFrom(address owner, uint256 amount) external;

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external;
}

interface IERC721Mintable {
    function safeMint(
        address recipient,
        uint256 tokenID,
        bytes memory data
    ) external;

    function mint(address recipient, uint256 tokenID) external;

    function burn(uint256 tokenID) external;
}

interface IAllowlist {
    function isAllowed(address) external view returns (bool);
}

interface IMinter {
    function mint(
        address _token,
        address _recipient,
        uint256 _amount
    ) external returns (bool);

    function transferOwnership(address newOwner) external;

    function owner() external view returns (address);
}

contract Lord is Owned {
    using Address for address;

    IAllowlist public standardTokenList;
    IMinter public tokenSafe;
    IAllowlist public proxyTokenList;
    IMinter public minterPool;

    constructor(
        IAllowlist _standardTokenList,
        IMinter _tokenSafe,
        IAllowlist _proxyTokenList,
        IMinter _minterPool
    ) public Owned() {
        standardTokenList = _standardTokenList;
        tokenSafe = _tokenSafe;
        proxyTokenList = _proxyTokenList;
        minterPool = _minterPool;
    }

    function burn(
        address _token,
        address _sender,
        uint256 _amount
    ) public onlyOwner {
        if (address(standardTokenList) != address(0) && standardTokenList.isAllowed(_token)) {
            // transfer token to standardTokenList
            _callOptionalReturn(
                _token,
                abi.encodeWithSelector(IToken(_token).transferFrom.selector, _sender, tokenSafe, _amount)
            );
            return;
        }
        if (address(proxyTokenList) != address(0) && proxyTokenList.isAllowed(_token)) {
            _callOptionalReturn(
                _token,
                abi.encodeWithSelector(IToken(_token).transferFrom.selector, _sender, address(this), _amount)
            );
            _callOptionalReturn(_token, abi.encodeWithSelector(IToken(_token).burn.selector, _amount));
            return;
        }
        _callOptionalReturn(_token, abi.encodeWithSelector(IToken(_token).burnFrom.selector, _sender, _amount));
    }

    function mint(
        address _token,
        address _recipient,
        uint256 _amount
    ) public onlyOwner {
        if (address(standardTokenList) != address(0) && standardTokenList.isAllowed(_token)) {
            require(tokenSafe.mint(_token, _recipient, _amount), "token safe mint failed");
            return;
        }
        if (address(proxyTokenList) != address(0) && proxyTokenList.isAllowed(_token)) {
            require(minterPool.mint(_token, _recipient, _amount), "proxy token mint failed");
        }
        _callOptionalReturn(_token, abi.encodeWithSelector(IToken(_token).mint.selector, _recipient, _amount));
    }

    function burnNFT(
        address _token,
        uint256 _tokenID
    ) public onlyOwner {
        IERC721Mintable(_token).burn(_tokenID);
    }

    function mintNFT(
        address _token,
        uint256 _tokenID,
        address _recipient,
        bytes memory _data
    ) public onlyOwner {
        IERC721Mintable(_token).safeMint(_recipient, _tokenID, _data);
    }

    function upgrade(address _newLord) public onlyOwner {
        if (minterPool.owner() == address(this)) {
            _callOptionalReturn(
                address(minterPool),
                abi.encodeWithSelector(minterPool.transferOwnership.selector, _newLord)
            );
        }
        if (tokenSafe.owner() == address(this)) {
            _callOptionalReturn(
                address(tokenSafe),
                abi.encodeWithSelector(tokenSafe.transferOwnership.selector, _newLord)
            );
        }
    }

    function _callOptionalReturn(address addr, bytes memory data) private {
        bytes memory returndata = addr.functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}
