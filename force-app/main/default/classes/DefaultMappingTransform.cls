public class DefaultMappingTransform implements MappingTransform {
    public Object transform(MappingTransformContext context) {
        return context == null ? null : context.sourceValue;
    }
}
