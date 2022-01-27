// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract CronosToken is ERC20PresetMinterPauser {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20PresetMinterPauser(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}
