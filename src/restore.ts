import * as cache from "@actions/cache";
import * as core from "@actions/core";

import {Events, State} from "./constants";
import * as utils from "./utils/actionUtils";

async function run(): Promise<void> {
    try {
        if (utils.isGhes()) {
            utils.logWarning("Cache action is not supported on GHES");
            utils.setCacheHitOutput(false);
            return;
        }

        // Validate inputs, this can cause task failure
        if (!utils.isValidEvent()) {
            utils.logWarning(
                `Event Validation Error: The event type ${
                    process.env[Events.Key]
                } is not supported because it's not tied to a branch or tag ref.`
            );
            return;
        }

        let primaryKey: string;
        // @ts-ignore
        primaryKey = process.env.ENV_IDENTIFIER;
        core.saveState(State.CachePrimaryKey, primaryKey);
        console.log(`#1 core.getState(State.CachePrimaryKey): ${core.getState(State.CachePrimaryKey)}`)

        let restoreKeys: string[];
        restoreKeys = [primaryKey];
        let cachePaths: string[];
        // @ts-ignore
        cachePaths = [process.env.ENV_CACHE];
        // const restoreKeys = utils.getInputAsArray(Inputs.RestoreKeys);
        // const cachePaths = utils.getInputAsArray(Inputs.Path, {required: true});

        try {
            const cacheKey = await cache.restoreCache(
                cachePaths,
                primaryKey,
                restoreKeys
            );
            if (!cacheKey) {
                core.info(
                    `Cache not found for input keys: ${[
                        primaryKey,
                        ...restoreKeys
                    ].join(", ")}`
                );
                return;
            }

            // Store the matched cache key
            utils.setCacheState(cacheKey);

            const isExactKeyMatch = utils.isExactKeyMatch(primaryKey, cacheKey);
            utils.setCacheHitOutput(isExactKeyMatch);

            core.info(`Cache restored from key: ${cacheKey}`);
        } catch (error) {
            if (error.name === cache.ValidationError.name) {
                throw error;
            } else {
                utils.logWarning(error.message);
                utils.setCacheHitOutput(false);
            }
        }
    } catch (error) {
        core.setFailed(error.message);
    }
}

run();

export default run;
