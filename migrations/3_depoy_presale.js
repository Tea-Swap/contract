const MINT = artifacts.require('Presale')

module.exports = function (deployer) {
    deployer.deploy(MINT, '0xc52B651d2005A7eB4DF03e9A0666A957A4B17f76', 1618823901, 1621397901);
};
