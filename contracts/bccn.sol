// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract BancCoin is ERC20Capped {
    address admin;
    address secondaryAdmin;

    event Minted(uint256 indexed amount, address indexed to);
    event TokensTransferred(uint256 indexed amount, address indexed to);
    event SecondaryAdminUpdated(string mssg, address indexed secondaryAdmin);

    modifier onlyOwner() {
        require(
            msg.sender == admin,
            "only admin is allowed to perform this action."
        );
        _;
    }

    constructor(
        address _admin,
        address _secondaryAdmin
    ) ERC20("BancCoin", "BCCN") ERC20Capped(700000000 * 10 ** 18) {
        admin = _admin;
        secondaryAdmin = _secondaryAdmin;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);

        emit Minted(amount, to);
    }

    function transferBnxForFiat(uint256 amount, address to) external {
        require(
            msg.sender == secondaryAdmin,
            "Only secondaryAdmin is allowed to transfer funds."
        );
        _transfer(address(this), to, amount);

        emit TokensTransferred(amount, to);
    }

    function updateSecondaryAdmin(
        address _newSecondaryAdmin
    ) external onlyOwner {
        secondaryAdmin = _newSecondaryAdmin;

        emit SecondaryAdminUpdated("SecondaryAdmin Updated.", secondaryAdmin);
    }
}
