import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

import org.neo4j.graphalgo.CommonEvaluators;
import org.neo4j.graphalgo.EstimateEvaluator;
import org.neo4j.graphalgo.GraphAlgoFactory;
import org.neo4j.graphalgo.PathFinder;
import org.neo4j.graphalgo.WeightedPath;
import org.neo4j.graphdb.Direction;
import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.graphdb.Node;
import org.neo4j.graphdb.PathExpander;
import org.neo4j.graphdb.PathExpanderBuilder;
import org.neo4j.graphdb.RelationshipType;
import org.neo4j.helpers.collection.Pair;
import org.neo4j.kernel.api.exceptions.InvalidArgumentsException;
import org.neo4j.procedure.Context;
import org.neo4j.procedure.Description;
import org.neo4j.procedure.Name;
import org.neo4j.procedure.Procedure;
import org.neo4j.procedure.TerminationGuard;
import org.neo4j.procedure.UserFunction;

import static org.neo4j.helpers.collection.MapUtil.map;
import static org.neo4j.procedure.Mode.READ;
import static org.neo4j.procedure.Mode.WRITE;

public class AtocProcedures
{
    @Context
    public GraphDatabaseService db;

    class TrainHeuristic implements EstimateEvaluator<Double>
    {
        private final EstimateEvaluator<Double> delegate;

        public TrainHeuristic(String latPropertyName, String lonPropertyName)
        {
            delegate = CommonEvaluators.geoEstimateEvaluator( latPropertyName, lonPropertyName );
        }

        @Override
        public Double getCost( Node node, Node goal )
        {
            Double costInMetres = delegate.getCost( node, goal );
            double costInSeconds = (costInMetres/ 70000) * 60 * 60;
            return costInSeconds;
        }
    }


    @Procedure("atoc.astar")
    @Description("training.markAStar(startNode, endNode, 'KNOWS|<WORKS_WITH|IS_MANAGER_OF>', 'distance','lat','lon') " +
            "YIELD path, weight - run A* with relationship property name as cost function")
    public Stream<WeightedPathResult> astar(
            @Name("startNode") Node startNode,
            @Name("endNode") Node endNode,
            @Name("relationshipTypesAndDirections") String relTypesAndDirs,
            @Name("weightPropertyName") String weightPropertyName,
            @Name("latPropertyName") String latPropertyName,
            @Name("lonPropertyName") String lonPropertyName) {

        PathFinder<WeightedPath> algo = GraphAlgoFactory.aStar(
                buildPathExpander(relTypesAndDirs),
                CommonEvaluators.doubleCostEvaluator(weightPropertyName),
                new TrainHeuristic(latPropertyName, lonPropertyName));
        return WeightedPathResult.streamWeightedPathResult(startNode, endNode, algo);
    }

    private PathExpander<Object> buildPathExpander( String relationshipsAndDirections) {
        PathExpanderBuilder builder = PathExpanderBuilder.empty();
        for (Pair<RelationshipType, Direction> pair : RelationshipTypeAndDirections
                .parse(relationshipsAndDirections)) {
            if (pair.first() == null) {
                if (pair.other() == null) {
                    builder = PathExpanderBuilder.allTypesAndDirections();
                } else {
                    builder = PathExpanderBuilder.allTypes(pair.other());
                }
            } else {
                if (pair.other() == null) {
                    builder = builder.add(pair.first());
                } else {
                    builder = builder.add(pair.first(), pair.other());
                }
            }
        }
        return builder.build();
    }
}

