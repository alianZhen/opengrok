/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * See LICENSE.txt included in this distribution for the specific
 * language governing permissions and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at LICENSE.txt.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright (c) 2018 Oracle and/or its affiliates. All rights reserved.
 */
package org.opensolaris.opengrok.web.api.v1.controller;

import org.glassfish.jersey.test.JerseyTest;
import org.junit.AfterClass;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;
import org.opengrok.suggest.Suggester;
import org.opensolaris.opengrok.configuration.RuntimeEnvironment;
import org.opensolaris.opengrok.configuration.SuggesterConfig;
import org.opensolaris.opengrok.index.Indexer;
import org.opensolaris.opengrok.search.QueryBuilder;
import org.opensolaris.opengrok.util.TestRepository;
import org.opensolaris.opengrok.web.api.v1.RestApp;
import org.opensolaris.opengrok.web.api.v1.suggester.provider.service.impl.SuggesterServiceImpl;

import javax.ws.rs.core.Application;
import java.io.File;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

import static org.awaitility.Awaitility.await;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.junit.Assert.assertThat;

public class SuggesterControllerProjectsDisabledTest extends JerseyTest {

    private static final RuntimeEnvironment env = RuntimeEnvironment.getInstance();

    private static TestRepository repository;

    @Override
    protected Application configure() {
        return new RestApp();
    }

    @BeforeClass
    public static void setUpClass() throws Exception {
        repository = new TestRepository();

        repository.create(SuggesterControllerTest.class.getResourceAsStream("/org/opensolaris/opengrok/index/source.zip"));

        env.setVerbose(false);
        env.setHistoryEnabled(false);
        env.setProjectsEnabled(false);
        env.setSourceRoot(repository.getSourceRoot() + File.separator + "java");

        Indexer.getInstance().prepareIndexer(env, true, true,
                Collections.singleton("__all__"),
                false, false, null, null, new ArrayList<>(), false);
        Indexer.getInstance().doIndexerExecution(true, null, null);

        env.getConfiguration().getSuggesterConfig().setRebuildCronConfig(null);
    }

    @AfterClass
    public static void tearDownClass() {
        repository.destroy();
    }

    @Before
    public void before() {
        await().atMost(15, TimeUnit.SECONDS).until(() -> getSuggesterProjectDataSize() == 1);

        env.getConfiguration().setSuggesterConfig(new SuggesterConfig());
    }

    private static int getSuggesterProjectDataSize() throws Exception {
        Field f = SuggesterServiceImpl.class.getDeclaredField("suggester");
        f.setAccessible(true);
        Suggester suggester = (Suggester) f.get(SuggesterServiceImpl.getInstance());

        Field f2 = Suggester.class.getDeclaredField("projectData");
        f2.setAccessible(true);

        return ((Map) f2.get(suggester)).size();
    }

    @Test
    public void suggestionsSimpleTest() {
        SuggesterControllerTest.Result res = target(SuggesterController.PATH)
                .queryParam("field", QueryBuilder.FULL)
                .queryParam(QueryBuilder.FULL, "inner")
                .request()
                .get(SuggesterControllerTest.Result.class);

        assertThat(res.suggestions.stream().map(r -> r.phrase).collect(Collectors.toList()),
                containsInAnyOrder("innermethod", "innerclass"));
    }

}
